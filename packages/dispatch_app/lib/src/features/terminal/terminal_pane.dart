import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:flutter_pty/flutter_pty.dart';

import '../../core/theme/app_theme.dart';
import '../../core/shortcuts/shortcut_registry.dart';
import '../../core/models/terminal_entry.dart';
import '../settings/settings_provider.dart';
import '../browser/browser_provider.dart';
import '../projects/projects_provider.dart';
import 'terminal_provider.dart';
import 'session_registry.dart';
import 'terminal_monitor.dart';

/// A single terminal pane using the xterm package for rendering
/// and flutter_pty for native PTY management.
class TerminalPane extends ConsumerStatefulWidget {
  final String terminalId;

  const TerminalPane({super.key, required this.terminalId});

  /// Global PTY registry so other widgets (e.g. FileTree) can write to a terminal.
  static final Map<String, Pty> ptyRegistry = {};
  /// Global xterm.Terminal registry — used to input text into the terminal.
  static final Map<String, xterm.Terminal> terminalRegistry = {};

  @override
  ConsumerState<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends ConsumerState<TerminalPane> {
  late xterm.Terminal _terminal;
  Pty? _pty;
  late TerminalMonitor _monitor;

  @override
  void initState() {
    super.initState();
    _terminal = xterm.Terminal(maxLines: 10000);
    TerminalPane.terminalRegistry[widget.terminalId] = _terminal;

    // Wire resize: when xterm recalculates size, resize the PTY
    _terminal.onResize = (w, h, pw, ph) {
      _pty?.resize(h, w);
    };

    _monitor = TerminalMonitor(
      onMetaUpdate: (terminalId, status) {
        ref.read(sessionRegistryProvider.notifier).updateMeta(
          terminalId,
          activityStatus: status,
        );
      },
    );

    _startPty();
  }

  void _startPty() {
    final entry = ref.read(terminalsProvider).terminals[widget.terminalId];
    if (entry == null) return;

    final shell = ref.read(settingsProvider).shell;
    final cwd = entry.cwd;
    final command = entry.command;

    // Spawn the PTY and register it globally
    _pty = Pty.start(
      shell,
      arguments: ['--login'],
      environment: {
        ...Platform.environment,
        'TERM': 'xterm-256color',
        'COLORTERM': 'truecolor',
      },
      workingDirectory: cwd,
    );

    final urlPattern = RegExp(r'https?://(localhost|127\.0\.0\.1)(:\d+)');
    final detectedPorts = <String>{};

    // Register PTY globally
    TerminalPane.ptyRegistry[widget.terminalId] = _pty!;

    ref.read(sessionRegistryProvider.notifier).register(
      widget.terminalId,
      pty: _pty,
    );

    // Wire PTY output → terminal + URL detection
    _pty!.output.cast<List<int>>().transform(const Utf8Decoder()).listen((data) {
      _terminal.write(data);

      // Feed output to SessionRegistry accumulator
      ref.read(sessionRegistryProvider.notifier).appendOutput(widget.terminalId, data);

      // Feed data to TerminalMonitor for idle/status detection
      _monitor.onData(widget.terminalId, data);

      // Detect localhost URLs
      for (final match in urlPattern.allMatches(data)) {
        final url = match.group(0)!;
        final port = Uri.tryParse(url)?.port.toString() ?? '';
        if (port.isNotEmpty && !detectedPorts.contains(port)) {
          detectedPorts.add(port);
          final groupId = ref.read(projectsProvider).activeGroupId;
          if (groupId != null) {
            ref.read(browserProvider.notifier).addTab(groupId, url);
          }
        }
      }
    });

    // Wire terminal input → PTY
    _terminal.onOutput = (data) {
      _pty!.write(const Utf8Encoder().convert(data));
    };

    // Handle PTY exit
    _pty!.exitCode.then((code) {
      if (mounted) {
        ref.read(terminalsProvider.notifier).updateStatus(
              widget.terminalId,
              TerminalStatus.exited,
              exitCode: code,
            );
      }
    });

    // If the command is not $SHELL, type it into the shell
    if (command != '\$SHELL' && command.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_pty != null) {
          _pty!.write(const Utf8Encoder().convert('$command\r'));
        }
      });
    }
  }

  /// Build shortcuts map that tells xterm to pass these key combos
  /// up to the Flutter Shortcuts widget instead of handling them.
  Map<ShortcutActivator, Intent> _buildShortcuts() {
    return AppShortcuts.bindings;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colorTheme = ref.watch(activeThemeProvider);
    final theme = AppTheme(colorTheme);
    final entry = ref.watch(terminalsProvider.select(
        (s) => s.terminals[widget.terminalId]));

    final isExited = entry?.status == TerminalStatus.exited;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Terminal header bar
        Container(
          height: AppTheme.terminalHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(bottom: BorderSide(color: theme.border, width: AppTheme.borderWidth)),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isExited
                      ? theme.accentRed
                      : (entry?.command.startsWith('claude') == true
                          ? theme.accentBlue
                          : theme.accentGreen),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  _headerLabel(entry),
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Split \u2318D  Close \u2318W',
                style: TextStyle(
                  color: theme.textSecondary.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        // Terminal view
        Expanded(
          child: Stack(
            children: [
              xterm.TerminalView(
                _terminal,
                padding: const EdgeInsets.all(8),
                shortcuts: _buildShortcuts(),
                textStyle: xterm.TerminalStyle.fromTextStyle(
                  TextStyle(
                    fontSize: settings.fontSize,
                    fontFamily: 'Menlo',
                    fontFamilyFallback: const ['SF Mono', 'Monaco', 'Courier New', 'monospace'],
                    fontWeight: FontWeight.normal,
                    height: 1.2,
                  ),
                  drawBoldTextInBrightColors: true,
                ),
                theme: xterm.TerminalTheme(
                  cursor: colorTheme.cursor,
                  selection: colorTheme.selection,
                  foreground: colorTheme.foreground,
                  background: colorTheme.background,
                  black: colorTheme.black,
                  red: colorTheme.red,
                  green: colorTheme.green,
                  yellow: colorTheme.yellow,
                  blue: colorTheme.blue,
                  magenta: colorTheme.magenta,
                  cyan: colorTheme.cyan,
                  white: colorTheme.white,
                  brightBlack: colorTheme.brightBlack,
                  brightRed: colorTheme.brightRed,
                  brightGreen: colorTheme.brightGreen,
                  brightYellow: colorTheme.brightYellow,
                  brightBlue: colorTheme.brightBlue,
                  brightMagenta: colorTheme.brightMagenta,
                  brightCyan: colorTheme.brightCyan,
                  brightWhite: colorTheme.brightWhite,
                  searchHitBackground: colorTheme.searchHitBackground,
                  searchHitBackgroundCurrent: colorTheme.searchHitBackgroundCurrent,
                  searchHitForeground: colorTheme.searchHitForeground,
                ),
                autofocus: true,
                hardwareKeyboardOnly: true,
              ),
              if (isExited)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Process exited with code ${entry?.exitCode ?? "unknown"}',
                          style: TextStyle(color: theme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Right-click terminal in sidebar to close',
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _headerLabel(TerminalEntry? entry) {
    if (entry == null) return '';
    final shortCmd = entry.command.split(' ').first.split('/').last;
    final folder = entry.cwd.split('/').last;
    if (entry.label != null && entry.label!.isNotEmpty) {
      return '${entry.label} \u2014 $folder';
    }
    return '$shortCmd \u2014 $folder';
  }

  @override
  void dispose() {
    _monitor.cleanup(widget.terminalId);
    try {
      ref.read(sessionRegistryProvider.notifier).unregister(widget.terminalId);
    } catch (_) {}
    TerminalPane.ptyRegistry.remove(widget.terminalId);
    TerminalPane.terminalRegistry.remove(widget.terminalId);
    _pty?.kill();
    super.dispose();
  }
}
