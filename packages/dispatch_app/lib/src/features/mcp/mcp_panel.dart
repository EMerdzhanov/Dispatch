import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import 'mcp_provider.dart';
import 'mcp_server.dart';

class McpPanel extends ConsumerStatefulWidget {
  final bool open;
  final VoidCallback onClose;

  const McpPanel({super.key, required this.open, required this.onClose});

  @override
  ConsumerState<McpPanel> createState() => _McpPanelState();
}

class _McpPanelState extends ConsumerState<McpPanel> {
  late TextEditingController _portCtrl;
  bool _tokenVisible = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _portCtrl = TextEditingController();
    // Refresh connection count periodically
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      ref.read(mcpServerProvider.notifier).refreshStatus();
    });
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final mcpState = ref.watch(mcpServerProvider);
    final colorTheme = ref.watch(activeThemeProvider);
    final theme = AppTheme(colorTheme);
    // Only update controller if value actually changed (avoids overwriting mid-edit)
    final portStr = mcpState.port.toString();
    if (_portCtrl.text != portStr) _portCtrl.text = portStr;

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent close on panel tap
            child: Material(
              color: Colors.transparent,
              child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 600),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border, width: 1),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.extension_outlined, color: theme.textPrimary, size: 18),
                        const SizedBox(width: 8),
                        Text('Integrations', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Icon(Icons.close, color: theme.textSecondary, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Server Status
                    _sectionLabel('MCP SERVER', theme),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Server', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => ref.read(mcpServerProvider.notifier).toggle(),
                          child: Container(
                            width: 40,
                            height: 22,
                            decoration: BoxDecoration(
                              color: mcpState.running ? theme.accentGreen : theme.border,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 150),
                              alignment: mcpState.running ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                width: 18,
                                height: 18,
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.textPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (mcpState.running) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Running on port ${mcpState.port} \u2022 ${mcpState.connectionCount} connected',
                        style: TextStyle(color: theme.textSecondary, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Connection Info
                    if (mcpState.running) ...[
                      _sectionLabel('CONNECTION', theme),
                      const SizedBox(height: 8),
                      _copyRow('URL', mcpState.httpUrl, theme),
                      if (mcpState.authEnabled && mcpState.authToken != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('Token', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _tokenVisible = !_tokenVisible),
                              child: Text(
                                _tokenVisible ? mcpState.authToken! : '\u2022' * 16,
                                style: TextStyle(color: theme.textPrimary, fontSize: 11, fontFamily: 'Menlo'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _copyButton(mcpState.authToken!, theme),
                          ],
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => ref.read(mcpServerProvider.notifier).regenerateToken(),
                          child: Text('Regenerate token', style: TextStyle(color: theme.accentBlue, fontSize: 11)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _sectionLabel('CLAUDE CODE CONFIG', theme),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                mcpState.claudeCodeConfig(),
                                style: TextStyle(color: theme.textSecondary, fontSize: 11, fontFamily: 'Menlo'),
                              ),
                            ),
                            _copyButton(mcpState.claudeCodeConfig(), theme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Settings
                    _sectionLabel('SETTINGS', theme),
                    const SizedBox(height: 8),
                    _settingRow('Port', theme, child: SizedBox(
                      width: 80,
                      height: 28,
                      child: TextField(
                        controller: _portCtrl,
                        style: TextStyle(color: theme.textPrimary, fontSize: 12),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: theme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: theme.border)),
                        ),
                        onSubmitted: (value) {
                          final port = int.tryParse(value);
                          if (port != null && port > 0 && port < 65536) {
                            ref.read(mcpServerProvider.notifier).setPort(port);
                          }
                        },
                      ),
                    )),
                    const SizedBox(height: 6),
                    _toggleRow('Token auth', mcpState.authEnabled, theme,
                        onChanged: (v) => ref.read(mcpServerProvider.notifier).setAuthEnabled(v)),
                    const SizedBox(height: 6),
                    _toggleRow('Network access', mcpState.bindAll, theme,
                        onChanged: (v) => ref.read(mcpServerProvider.notifier).setBindAll(v),
                        warning: 'Exposes server to local network'),

                    // Activity Log
                    if (mcpState.running && mcpState.activityLog.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel('RECENT ACTIVITY', theme),
                      const SizedBox(height: 8),
                      ...mcpState.activityLog.take(10).map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Text(
                                  '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: theme.textSecondary, fontSize: 10, fontFamily: 'Menlo'),
                                ),
                                const SizedBox(width: 8),
                                Text(entry.toolName, style: TextStyle(color: theme.textPrimary, fontSize: 11)),
                                const Spacer(),
                                Text(entry.agentId, style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, AppTheme theme) {
    return Text(text, style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1));
  }

  Widget _copyRow(String label, String value, AppTheme theme) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
        const Spacer(),
        Text(value, style: TextStyle(color: theme.textPrimary, fontSize: 11, fontFamily: 'Menlo')),
        const SizedBox(width: 6),
        _copyButton(value, theme),
      ],
    );
  }

  Widget _copyButton(String text, AppTheme theme) {
    return GestureDetector(
      onTap: () => Clipboard.setData(ClipboardData(text: text)),
      child: Icon(Icons.copy, size: 12, color: theme.textSecondary),
    );
  }

  Widget _settingRow(String label, AppTheme theme, {required Widget child}) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 13)),
        const Spacer(),
        child,
      ],
    );
  }

  Widget _toggleRow(String label, bool value, AppTheme theme,
      {required ValueChanged<bool> onChanged, String? warning}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: () => onChanged(!value),
              child: Container(
                width: 36,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? theme.accentGreen : theme.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 150),
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.textPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (warning != null && value)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(warning, style: TextStyle(color: theme.accentYellow, fontSize: 10)),
          ),
      ],
    );
  }
}
