import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import 'mcp_provider.dart';

class McpPanel extends ConsumerStatefulWidget {
  final bool open;
  final VoidCallback onClose;

  const McpPanel({super.key, required this.open, required this.onClose});

  @override
  ConsumerState<McpPanel> createState() => _McpPanelState();
}

class _McpPanelState extends ConsumerState<McpPanel> {
  late TextEditingController _portCtrl;
  late TextEditingController _tunnelNameCtrl;
  late TextEditingController _tunnelUrlCtrl;
  late TextEditingController _relayHostCtrl;
  bool _tokenVisible = false;
  bool _publicAccessOpen = false;
  bool _namedTunnelOpen = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _portCtrl = TextEditingController();
    _tunnelNameCtrl = TextEditingController();
    _tunnelUrlCtrl = TextEditingController();
    _relayHostCtrl = TextEditingController();
    ref.read(mcpServerProvider.notifier).checkCloudflared();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      ref.read(mcpServerProvider.notifier).refreshStatus();
    });
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _tunnelNameCtrl.dispose();
    _tunnelUrlCtrl.dispose();
    _relayHostCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final mcpState = ref.watch(mcpServerProvider);
    final colorTheme = ref.watch(activeThemeProvider);
    final theme = AppTheme(colorTheme);

    final portStr = mcpState.port.toString();
    if (_portCtrl.text != portStr) _portCtrl.text = portStr;
    if (_relayHostCtrl.text != mcpState.relayHost) _relayHostCtrl.text = mcpState.relayHost;

    final tunnelDirty =
        _tunnelNameCtrl.text != (mcpState.tunnelName ?? '') ||
        _tunnelUrlCtrl.text != (mcpState.tunnelCustomUrl ?? '');

    ref.listen(
      mcpServerProvider.select((s) => (s.tunnelName, s.tunnelCustomUrl)),
      (prev, next) {
        final prevName = prev?.$1 ?? '';
        final prevUrl = prev?.$2 ?? '';
        if (_tunnelNameCtrl.text != prevName || _tunnelUrlCtrl.text != prevUrl) return;
        final tn = next.$1 ?? '';
        if (_tunnelNameCtrl.text != tn) _tunnelNameCtrl.text = tn;
        final tu = next.$2 ?? '';
        if (_tunnelUrlCtrl.text != tu) _tunnelUrlCtrl.text = tu;
      },
    );

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 480,
                constraints: const BoxConstraints(maxHeight: 700),
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
                            child: _Toggle(value: mcpState.running, theme: theme, size: 40),
                          ),
                        ],
                      ),
                      if (mcpState.running) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Port ${mcpState.port} \u2022 ${mcpState.connectionCount} connected',
                          style: TextStyle(color: theme.textSecondary, fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Connection URL
                      if (mcpState.running) ...[
                        _sectionLabel('CONNECTION', theme),
                        const SizedBox(height: 8),
                        _copyRow('URL', mcpState.httpUrl, theme),
                        if (mcpState.authEnabled && mcpState.authToken != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Token', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _tokenVisible = !_tokenVisible),
                                  child: Text(
                                    _tokenVisible ? mcpState.authToken! : '\u2022' * 16,
                                    style: TextStyle(color: theme.textPrimary, fontSize: 11, fontFamily: 'Menlo'),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _CopyButton(text: mcpState.authToken!, theme: theme),
                            ],
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => ref.read(mcpServerProvider.notifier).regenerateToken(),
                            child: Text('Regenerate token', style: TextStyle(color: theme.accentBlue, fontSize: 11)),
                          ),
                        ],
                        // Public URL toggle (always visible)
                        const SizedBox(height: 10),
                        if (!mcpState.cloudflaredAvailable) ...[
                          Text(
                            'Install cloudflared for public URLs: brew install cloudflared',
                            style: TextStyle(color: theme.textSecondary, fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => ref.read(mcpServerProvider.notifier).checkCloudflared(),
                            child: Text('Re-check', style: TextStyle(color: theme.accentBlue, fontSize: 11)),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Text('Public URL', style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  if (mcpState.tunnelRunning) {
                                    ref.read(mcpServerProvider.notifier).stopTunnel();
                                  } else if (!mcpState.tunnelStarting) {
                                    ref.read(mcpServerProvider.notifier).startTunnel();
                                  }
                                },
                                child: _Toggle(
                                  value: mcpState.tunnelRunning,
                                  pending: mcpState.tunnelStarting,
                                  theme: theme,
                                ),
                              ),
                            ],
                          ),
                          if (mcpState.tunnelStarting)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Starting tunnel...', style: TextStyle(color: theme.accentYellow, fontSize: 11)),
                            ),
                          if (mcpState.tunnelRunning && !mcpState.tunnelStarting)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Temporary URL — changes on restart.',
                                style: TextStyle(color: theme.textSecondary, fontSize: 10),
                              ),
                            ),
                        ],
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

                      // ── Advanced (collapsible) ─────────────────────────
                      if (mcpState.running) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => setState(() => _publicAccessOpen = !_publicAccessOpen),
                          child: Row(
                            children: [
                              Icon(
                                _publicAccessOpen ? Icons.expand_less : Icons.expand_more,
                                size: 14,
                                color: theme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text('ADVANCED', style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                            ],
                          ),
                        ),
                        if (_publicAccessOpen) ...[
                          const SizedBox(height: 12),

                          // ── Card 1: Permanent Cloudflare Tunnel ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: mcpState.tunnelRunning && mcpState.hasNamedTunnel ? theme.accentGreen : theme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.cloud_outlined, size: 16, color: theme.textPrimary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Permanent Tunnel', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                                          Text(
                                            'Cloudflare \u2022 your own domain',
                                            style: TextStyle(color: theme.textSecondary, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        if (mcpState.tunnelRunning) {
                                          ref.read(mcpServerProvider.notifier).stopTunnel();
                                        } else if (!mcpState.tunnelStarting) {
                                          ref.read(mcpServerProvider.notifier).startTunnel();
                                        }
                                      },
                                      child: _Toggle(
                                        value: mcpState.tunnelRunning && mcpState.hasNamedTunnel,
                                        pending: mcpState.tunnelStarting,
                                        theme: theme,
                                      ),
                                    ),
                                  ],
                                ),
                                if (!mcpState.cloudflaredAvailable) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'Requires cloudflared: brew install cloudflared',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 10),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => ref.read(mcpServerProvider.notifier).checkCloudflared(),
                                    child: Text('Re-check', style: TextStyle(color: theme.accentBlue, fontSize: 11)),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () => setState(() => _namedTunnelOpen = !_namedTunnelOpen),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _namedTunnelOpen ? Icons.expand_less : Icons.expand_more,
                                          size: 12,
                                          color: theme.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text('Setup instructions', style: TextStyle(color: theme.accentBlue, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  if (_namedTunnelOpen) ...[
                                    const SizedBox(height: 8),
                                    _stepHeader('1. Install cloudflared', theme),
                                    const SizedBox(height: 4),
                                    _codeBlock('brew install cloudflared', theme),
                                    const SizedBox(height: 10),
                                    _stepHeader('2. Log in to Cloudflare', theme),
                                    const SizedBox(height: 4),
                                    _codeBlock('cloudflared tunnel login', theme),
                                    const SizedBox(height: 10),
                                    _stepHeader('3. Create a named tunnel', theme),
                                    const SizedBox(height: 4),
                                    _codeBlock('cloudflared tunnel create dispatch', theme),
                                    const SizedBox(height: 10),
                                    _stepHeader('4. Point a subdomain to it', theme),
                                    const SizedBox(height: 4),
                                    _codeBlock('cloudflared tunnel route dns dispatch \\\n  dispatch.yourdomain.com', theme),
                                    const SizedBox(height: 10),
                                    _stepHeader('5. Fill in below and hit Save', theme),
                                  ],
                                  const SizedBox(height: 10),
                                  _settingRow('Tunnel name', theme, child: SizedBox(
                                    width: 140,
                                    height: 28,
                                    child: TextField(
                                      controller: _tunnelNameCtrl,
                                      style: TextStyle(color: theme.textPrimary, fontSize: 12),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: 'e.g. dispatch',
                                        hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5), fontSize: 12),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: theme.border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: theme.border)),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  )),
                                  const SizedBox(height: 6),
                                  _settingRow('Tunnel URL', theme, child: SizedBox(
                                    width: 220,
                                    height: 28,
                                    child: TextField(
                                      controller: _tunnelUrlCtrl,
                                      style: TextStyle(color: theme.textPrimary, fontSize: 12),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: 'https://dispatch.yourdomain.com',
                                        hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5), fontSize: 10),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: theme.border)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: theme.border)),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  )),
                                  if (tunnelDirty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            ref.read(mcpServerProvider.notifier).setTunnelConfig(
                                              name: _tunnelNameCtrl.text,
                                              customUrl: _tunnelUrlCtrl.text,
                                            );
                                            setState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: theme.accentGreen,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('Save', style: TextStyle(color: theme.background, fontSize: 11, fontWeight: FontWeight.w600)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            _tunnelNameCtrl.text = mcpState.tunnelName ?? '';
                                            _tunnelUrlCtrl.text = mcpState.tunnelCustomUrl ?? '';
                                            setState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: theme.border),
                                            ),
                                            child: Text('Cancel', style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ── Card 2: Relay Server ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: mcpState.relayConnected ? theme.accentGreen : theme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.swap_horiz, size: 16, color: theme.textPrimary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Relay Server', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                                          Text(
                                            mcpState.relayConnected
                                                ? '\u2022 Connected'
                                                : 'Self-hosted WebSocket relay',
                                            style: TextStyle(
                                              color: mcpState.relayConnected ? theme.accentGreen : theme.textSecondary,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => ref.read(mcpServerProvider.notifier)
                                          .setRelayEnabled(!mcpState.relayEnabled),
                                      child: _Toggle(
                                        value: mcpState.relayEnabled,
                                        pending: mcpState.relayEnabled && !mcpState.relayConnected,
                                        theme: theme,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _settingRow('Host', theme, child: SizedBox(
                                  width: 220,
                                  height: 28,
                                  child: TextField(
                                    controller: _relayHostCtrl,
                                    style: TextStyle(color: theme.textPrimary, fontSize: 11),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'wss://relay.example.com:3901',
                                      hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5), fontSize: 10),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: theme.border)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: theme.border)),
                                    ),
                                    onSubmitted: (value) {
                                      ref.read(mcpServerProvider.notifier).setRelayHost(value.trim());
                                    },
                                  ),
                                )),
                                if (mcpState.relayHost.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Enter your relay server WebSocket URL.',
                                      style: TextStyle(color: theme.textSecondary, fontSize: 10),
                                    ),
                                  ),
                                if (mcpState.relayConnected && mcpState.relayClientId != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Permanent URL — survives restarts.',
                                    style: TextStyle(color: theme.textSecondary, fontSize: 10),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],

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

  Widget _sectionLabel(String text, AppTheme theme) =>
      Text(text, style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1));

  Widget _copyRow(String label, String value, AppTheme theme) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: theme.textPrimary, fontSize: 11, fontFamily: 'Menlo'),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 6),
        _CopyButton(text: value, theme: theme),
      ],
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

  Widget _stepHeader(String text, AppTheme theme) =>
      Text(text, style: TextStyle(color: theme.textPrimary, fontSize: 10, fontWeight: FontWeight.w600));

  Widget _codeBlock(String code, AppTheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: theme.background, borderRadius: BorderRadius.circular(4)),
      child: Text(code, style: TextStyle(color: theme.textSecondary, fontSize: 10, fontFamily: 'Menlo', height: 1.6)),
    );
  }

  Widget _toggleRow(String label, bool value, AppTheme theme,
      {required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 13)),
        const Spacer(),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: _Toggle(value: value, theme: theme),
        ),
      ],
    );
  }
}

/// Reusable toggle widget with optional pending/yellow state.
class _Toggle extends StatelessWidget {
  final bool value;
  final bool pending;
  final AppTheme theme;
  final double size;

  const _Toggle({required this.value, required this.theme, this.pending = false, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final color = pending
        ? theme.accentYellow
        : value
            ? theme.accentGreen
            : theme.border;
    final knobSize = size * 0.44;
    final height = size * 0.55;

    return Container(
      width: size,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: (value || pending) ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: knobSize,
          height: knobSize,
          margin: EdgeInsets.all(height * 0.1),
          decoration: BoxDecoration(color: theme.textPrimary, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String text;
  final AppTheme theme;
  const _CopyButton({required this.text, required this.theme});
  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleCopy,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _copied
            ? Icon(Icons.check, size: 12, color: widget.theme.accentGreen, key: const ValueKey('check'))
            : Icon(Icons.copy, size: 12, color: widget.theme.textSecondary, key: const ValueKey('copy')),
      ),
    );
  }
}
