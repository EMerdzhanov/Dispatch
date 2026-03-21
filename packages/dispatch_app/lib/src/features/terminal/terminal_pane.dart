import 'package:dispatch_terminal/dispatch_terminal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/terminal_entry.dart';
import '../settings/settings_provider.dart';
import 'session_registry.dart';
import 'terminal_provider.dart';

/// A single terminal pane that wraps [TerminalView] and connects to a [PtySession].
class TerminalPane extends ConsumerStatefulWidget {
  final String terminalId;

  const TerminalPane({super.key, required this.terminalId});

  @override
  ConsumerState<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends ConsumerState<TerminalPane> {
  late Terminal _terminal;
  PtySession? _session;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(cols: 80, rows: 24);
  }

  void _connectSession(PtySession session) {
    if (_connected) return;
    _session = session;
    _connected = true;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sessions = ref.watch(sessionRegistryProvider);
    final session = sessions[widget.terminalId];
    final entry = ref.watch(terminalsProvider.select(
        (s) => s.terminals[widget.terminalId]));

    if (session != null) {
      _connectSession(session);
    }

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
              TerminalView(
                terminal: _terminal,
                dataStream: _session?.dataStream ?? const Stream.empty(),
                onInput: (data) => _session?.write(data),
                fontSize: settings.fontSize,
                fontFamily: settings.fontFamily,
                theme: TerminalTheme.dark,
                autofocus: true,
                onResize: (cols, rows) => _session?.resize(cols, rows),
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

  String _headerLabel(dynamic entry) {
    if (entry == null) return '';
    final command = entry.command as String;
    final cwd = entry.cwd as String;
    final shortCmd = command.split(' ').first.split('/').last;
    final folder = cwd.split('/').last;
    final label = entry.label;
    if (label != null && (label as String).isNotEmpty) {
      return '$label — $folder';
    }
    return '$shortCmd — $folder';
  }

  @override
  void dispose() {
    // Don't dispose the session — it's managed by PtyManager in app.dart
    super.dispose();
  }
}
