import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'agent_status_checker.dart';
import 'settings_provider.dart';

class AgentStatusPanel extends ConsumerStatefulWidget {
  const AgentStatusPanel({super.key});

  @override
  ConsumerState<AgentStatusPanel> createState() => _AgentStatusPanelState();
}

class _AgentStatusPanelState extends ConsumerState<AgentStatusPanel>
    with WidgetsBindingObserver {
  bool _initialCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-refresh when app regains focus (user may have just authed)
    if (state == AppLifecycleState.resumed) {
      ref.read(agentStatusProvider.notifier).checkAll(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final statuses = ref.watch(agentStatusProvider);

    // Trigger initial check
    if (!_initialCheckDone) {
      _initialCheckDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(agentStatusProvider.notifier).checkAll();
      });
    }

    final isAnyChecking = statuses.values.any((s) => s.state == 'checking');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Refresh All
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Agent Status',
                  style: theme.titleStyle
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (isAnyChecking)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: theme.accentBlue,
                  ),
                )
              else
                GestureDetector(
                  onTap: () => ref
                      .read(agentStatusProvider.notifier)
                      .checkAll(force: true),
                  child: Text(
                    'Refresh All',
                    style:
                        TextStyle(color: theme.accentBlue, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),

        // Agent list
        ...knownAgents.map((agentDef) {
          final status = statuses[agentDef.name];
          if (status == null) return const SizedBox.shrink();
          return _AgentRow(
            status: status,
            agentDef: agentDef,
            theme: theme,
            onRecheck: () => ref
                .read(agentStatusProvider.notifier)
                .checkOne(agentDef.name),
          );
        }),
      ],
    );
  }
}

class _AgentRow extends StatefulWidget {
  final AgentStatus status;
  final AgentDef agentDef;
  final AppTheme theme;
  final VoidCallback onRecheck;

  const _AgentRow({
    required this.status,
    required this.agentDef,
    required this.theme,
    required this.onRecheck,
  });

  @override
  State<_AgentRow> createState() => _AgentRowState();
}

class _AgentRowState extends State<_AgentRow> {
  bool _hovered = false;

  Color _statusColor() => switch (widget.status.state) {
        'ok' => Colors.green,
        'auth_required' => Colors.orange,
        'not_installed' => Colors.red.shade400,
        _ => Colors.grey,
      };

  String _statusText() => switch (widget.status.state) {
        'ok' =>
          'Authenticated${widget.status.version != null ? ' · ${widget.status.version}' : ''}',
        'auth_required' =>
          'Auth required${widget.status.detail != null ? ' · ${widget.status.detail}' : ''}',
        'not_installed' => 'Not installed',
        _ => 'Checking...',
      };

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: _hovered ? theme.surfaceLight : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusColor(),
              ),
            ),
            const SizedBox(width: 10),

            // Name and status text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.status.name,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _statusText(),
                    style: TextStyle(
                      color: _statusColor(),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons (visible on hover)
            if (_hovered || widget.status.state == 'auth_required') ...[
              if (widget.status.state == 'auth_required')
                GestureDetector(
                  onTap: () => _showFixDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Fix',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (_hovered) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onRecheck,
                  child: Icon(
                    Icons.refresh,
                    size: 14,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showFixDialog(BuildContext context) {
    final theme = widget.theme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.border),
        ),
        title: Text(
          'Fix ${widget.agentDef.name}',
          style: TextStyle(color: theme.textPrimary, fontSize: 14),
        ),
        content: Text(
          widget.agentDef.fixDetail,
          style: TextStyle(color: theme.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onRecheck();
            },
            child: Text(
              'Re-check',
              style: TextStyle(color: theme.accentBlue, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
