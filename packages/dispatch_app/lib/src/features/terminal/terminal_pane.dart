import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:flutter_pty/flutter_pty.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/terminal_entry.dart';
import '../settings/settings_provider.dart';
import '../browser/browser_provider.dart';
import '../projects/projects_provider.dart';
import 'terminal_provider.dart';

/// A single terminal pane using the xterm package for rendering
/// and flutter_pty for native PTY management.
class TerminalPane extends ConsumerStatefulWidget {
  final String terminalId;

  const TerminalPane({super.key, required this.terminalId});

  @override
  ConsumerState<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends ConsumerState<TerminalPane> {
  late xterm.Terminal _terminal;
  Pty? _pty;

  @override
  void initState() {
    super.initState();
    _terminal = xterm.Terminal(maxLines: 10000);

    // Wire resize: when xterm recalculates size, resize the PTY
    _terminal.onResize = (w, h, pw, ph) {
      _pty?.resize(h, w);
    };

    _startPty();
  }

  void _startPty() {
    final entry = ref.read(terminalsProvider).terminals[widget.terminalId];
    if (entry == null) return;

    final shell = ref.read(settingsProvider).shell;
    final cwd = entry.cwd;
    final command = entry.command;

    // Spawn the PTY using flutter_pty
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

    // Wire PTY output → terminal + URL detection
    _pty!.output.cast<List<int>>().transform(const Utf8Decoder()).listen((data) {
      _terminal.write(data);

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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final entry = ref.watch(terminalsProvider.select(
        (s) => s.terminals[widget.terminalId]));

    final isExited = entry?.status == TerminalStatus.exited;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Terminal header bar
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isExited
                      ? AppTheme.accentRed
                      : (entry?.command.startsWith('claude') == true
                          ? AppTheme.accentBlue
                          : AppTheme.accentGreen),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _headerLabel(entry),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Split \u2318D  Close \u2318W',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
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
                textStyle: xterm.TerminalStyle.fromTextStyle(TextStyle(
                  fontSize: settings.fontSize,
                  fontFamily: 'SF Mono',
                  fontFamilyFallback: const ['Menlo', 'Monaco', 'Courier New', 'monospace'],
                  fontWeight: FontWeight.w100,
                  height: 1.2,
                )),
                theme: const xterm.TerminalTheme(
                  cursor: Color(0xFFCCCCCC),
                  selection: Color(0xFF16213E),
                  foreground: Color(0xFFCCCCCC),
                  background: Color(0xFF0A0A1A),
                  black: Color(0xFF0A0A1A),
                  red: Color(0xFFE94560),
                  green: Color(0xFF4CAF50),
                  yellow: Color(0xFFF5A623),
                  blue: Color(0xFF53A8FF),
                  magenta: Color(0xFFC678DD),
                  cyan: Color(0xFF56B6C2),
                  white: Color(0xFFCCCCCC),
                  brightBlack: Color(0xFF555555),
                  brightRed: Color(0xFFFF6B81),
                  brightGreen: Color(0xFF69F0AE),
                  brightYellow: Color(0xFFFFD740),
                  brightBlue: Color(0xFF82B1FF),
                  brightMagenta: Color(0xFFE1ACFF),
                  brightCyan: Color(0xFF84FFFF),
                  brightWhite: Color(0xFFFFFFFF),
                  searchHitBackground: Color(0xFF444444),
                  searchHitBackgroundCurrent: Color(0xFFFFFF00),
                  searchHitForeground: Color(0xFF000000),
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
                          style: const TextStyle(color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Right-click terminal in sidebar to close',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
    _pty?.kill();
    super.dispose();
  }
}
