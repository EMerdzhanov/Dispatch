import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ConsoleMessage {
  final DateTime timestamp;
  final String level; // 'info', 'warn', 'error'
  final String message;
  final String? source;

  ConsoleMessage({required this.timestamp, required this.level, required this.message, this.source});
}

class BrowserConsole extends StatefulWidget {
  final List<ConsoleMessage> messages;
  final VoidCallback onClear;
  final bool pipeToTerminal;
  final VoidCallback onTogglePipe;

  const BrowserConsole({
    super.key,
    required this.messages,
    required this.onClear,
    required this.pipeToTerminal,
    required this.onTogglePipe,
  });

  @override
  State<BrowserConsole> createState() => _BrowserConsoleState();
}

class _BrowserConsoleState extends State<BrowserConsole> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final errorCount = widget.messages.where((m) => m.level == 'error').length;
    final totalCount = widget.messages.length;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle bar
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
              child: Row(
                children: [
                  const Text('Console', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  if (totalCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$totalCount', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                    ),
                  ],
                  if (errorCount > 0) ...[
                    const SizedBox(width: 6),
                    Text('$errorCount errors', style: const TextStyle(color: AppTheme.accentRed, fontSize: 9)),
                  ],
                  const Spacer(),
                  Text(_expanded ? '\u25BC' : '\u25B2', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                ],
              ),
            ),
          ),
          // Console messages
          if (_expanded) ...[
            Container(
              height: 150,
              color: AppTheme.background,
              child: widget.messages.isEmpty
                  ? const Center(child: Text('No console messages yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)))
                  : ListView.builder(
                      itemCount: widget.messages.length,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemBuilder: (context, index) {
                        final msg = widget.messages[index];
                        final icon = msg.level == 'error' ? '\u2715' : msg.level == 'warn' ? '\u26A0' : '\u2139';
                        final color = msg.level == 'error'
                            ? AppTheme.accentRed
                            : msg.level == 'warn'
                                ? AppTheme.accentYellow
                                : AppTheme.textSecondary;
                        final time = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}:${msg.timestamp.second.toString().padLeft(2, '0')}';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: 1),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(time, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                              const SizedBox(width: 6),
                              Text(icon, style: TextStyle(color: color, fontSize: 10)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(msg.message, style: TextStyle(color: color, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Actions bar
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onClear,
                    child: const Text('Clear', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onTogglePipe,
                    child: Text(
                      widget.pipeToTerminal ? '\u2713 Piping to Terminal' : 'Pipe to Terminal',
                      style: TextStyle(
                        color: widget.pipeToTerminal ? AppTheme.accentGreen : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
