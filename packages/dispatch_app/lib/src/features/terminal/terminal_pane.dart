import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' as xterm;

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
///
/// PTY lifecycle is owned by SessionRegistry, NOT by this widget.
/// The widget is a thin view that survives unmount/remount without
/// killing the underlying PTY process.
class TerminalPane extends ConsumerStatefulWidget {
  final String terminalId;

  const TerminalPane({super.key, required this.terminalId});

  @override
  ConsumerState<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends ConsumerState<TerminalPane> {
  late TerminalMonitor _monitor;

  @override
  void initState() {
    super.initState();

    _monitor = TerminalMonitor(
      onMetaUpdate: (terminalId, status) {
        Future.delayed(Duration.zero, () {
          if (mounted) {
            ref.read(sessionRegistryProvider.notifier).updateMeta(
              terminalId,
              activityStatus: status,
            );
          }
        });
      },
    );

    Future.delayed(Duration.zero, () {
      if (mounted) _ensurePty();
    });
  }

  void _ensurePty() {
    final registry = ref.read(sessionRegistryProvider.notifier);

    // If terminal object doesn't exist yet, create and register it
    if (registry.getTerminal(widget.terminalId) == null) {
      final terminal = xterm.Terminal(maxLines: 10000);
      registry.register(widget.terminalId, terminal: terminal);
    }

    // If PTY doesn't exist yet, spawn it
    if (registry.getPty(widget.terminalId) == null) {
      final entry = ref.read(terminalsProvider).terminals[widget.terminalId];
      if (entry == null) return;

      final shell = ref.read(settingsProvider).shell;
      final urlPattern = RegExp(r'https?://(localhost|127\.0\.0\.1)(:\d+)');
      final detectedPorts = <String>{};

      registry.spawnPty(
        widget.terminalId,
        shell: shell,
        cwd: entry.cwd,
        command: entry.command,
        onOutput: (data) {
          if (!mounted) return;
          _monitor.onData(widget.terminalId, data);

          // Detect localhost URLs
          for (final match in urlPattern.allMatches(data)) {
            final url = match.group(0)!;
            final port = Uri.tryParse(url)?.port.toString() ?? '';
            if (port.isNotEmpty && !detectedPorts.contains(port)) {
              detectedPorts.add(port);
              Future.delayed(Duration.zero, () {
                if (mounted) {
                  final groupId = ref.read(projectsProvider).activeGroupId;
                  if (groupId != null) {
                    ref.read(browserProvider.notifier).addTab(groupId, url);
                  }
                }
              });
            }
          }
        },
        onExit: (code) {
          Future.delayed(Duration.zero, () {
            if (mounted) {
              ref.read(terminalsProvider.notifier).updateStatus(
                widget.terminalId,
                TerminalStatus.exited,
                exitCode: code,
              );
            }
          });
        },
      );
    }
  }

  Map<ShortcutActivator, Intent> _buildShortcuts() {
    return {
      ...xterm.defaultTerminalShortcuts,
      ...AppShortcuts.bindings,
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colorTheme = ref.watch(activeThemeProvider);
    final theme = ref.watch(appThemeProvider);
    final entry = ref.watch(terminalsProvider.select(
        (s) => s.terminals[widget.terminalId]));
    final terminal = ref.watch(sessionRegistryProvider.select(
        (s) => s[widget.terminalId]?.terminal));

    if (terminal == null) {
      return Center(
        child: Text('Terminal not found', style: TextStyle(color: theme.textSecondary)),
      );
    }

    final isExited = entry?.status == TerminalStatus.exited;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isExited ? theme.accentRed
                      : (entry?.command.startsWith('claude') == true ? theme.accentBlue : theme.accentGreen),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(_headerLabel(entry),
                  style: TextStyle(color: theme.textSecondary, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('Split \u2318D  Close \u2318W',
                style: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5), fontSize: 10),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FocusScope(
                skipTraversal: true,
                child: xterm.TerminalView(
                terminal,
                padding: const EdgeInsets.all(8),
                shortcuts: _buildShortcuts(),
                textStyle: xterm.TerminalStyle.fromTextStyle(
                  TextStyle(
                    fontSize: settings.fontSize,
                    fontFamily: 'Menlo',
                    fontFamilyFallback: const ['SF Mono', 'Monaco', 'Courier New', 'monospace'],
                    fontWeight: FontWeight.normal,
                    height: 1.0,
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
              ),
              if (isExited)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Process exited with code ${entry?.exitCode ?? "unknown"}',
                          style: TextStyle(color: theme.textPrimary)),
                        const SizedBox(height: 8),
                        Text('Right-click terminal in sidebar to close',
                          style: TextStyle(color: theme.textSecondary, fontSize: 12)),
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
    // DO NOT kill the PTY here — only disconnect the monitor.
    // PTY lives in SessionRegistry and survives widget unmount.
    _monitor.cleanup(widget.terminalId);
    super.dispose();
  }
}
