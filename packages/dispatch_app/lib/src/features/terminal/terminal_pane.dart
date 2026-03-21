import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:flutter_pty/flutter_pty.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/terminal_entry.dart';
import '../settings/settings_provider.dart';
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

    // Wire PTY output → terminal
    _pty!.output.cast<List<int>>().transform(const Utf8Decoder()).listen((data) {
      _terminal.write(data);
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
                textStyle: xterm.TerminalStyle(
                  fontSize: settings.fontSize,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: const ['SF Mono', 'Monaco', 'Courier New', 'monospace'],
                ),
                theme: const xterm.TerminalTheme(
                  cursor: Color(0xFFAAAAAA),
                  selection: Color(0x803A6FD6),
                  foreground: Color(0xFFCCCCCC),
                  background: Color(0xFF0A0A1A),
                  black: Color(0xFF000000),
                  red: Color(0xFFCD0000),
                  green: Color(0xFF00CD00),
                  yellow: Color(0xFFCDCD00),
                  blue: Color(0xFF0000EE),
                  magenta: Color(0xFFCD00CD),
                  cyan: Color(0xFF00CDCD),
                  white: Color(0xFFE5E5E5),
                  brightBlack: Color(0xFF7F7F7F),
                  brightRed: Color(0xFFFF0000),
                  brightGreen: Color(0xFF00FF00),
                  brightYellow: Color(0xFFFFFF00),
                  brightBlue: Color(0xFF5C5CFF),
                  brightMagenta: Color(0xFFFF00FF),
                  brightCyan: Color(0xFF00FFFF),
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
