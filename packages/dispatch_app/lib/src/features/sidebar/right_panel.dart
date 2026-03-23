import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../projects/project_panel.dart';
import '../alfa/alfa_panel.dart';
import 'file_tree.dart';

/// Collapsible right panel containing File Tree and Tasks/Notes/Vault.
class RightPanel extends ConsumerStatefulWidget {
  const RightPanel({super.key});

  @override
  ConsumerState<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends ConsumerState<RightPanel> {
  bool _collapsed = false;
  String _tab = 'alfa'; // 'files' | 'project' | 'alfa'

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);

    if (_collapsed) {
      return GestureDetector(
        onTap: () => setState(() => _collapsed = false),
        child: Container(
          width: 28,
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(left: BorderSide(color: theme.border, width: AppTheme.borderWidth)),
          ),
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                'FILES & NOTES',
                style: TextStyle(color: theme.textSecondary, fontSize: 9, letterSpacing: 1.5),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(left: BorderSide(color: theme.border, width: AppTheme.borderWidth)),
      ),
      child: Column(
        children: [
          // Header with tabs and collapse button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
            child: Row(
              children: [
                // Tab track
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: theme.tabTrack,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: theme.tabTrackBorder, width: 1),
                    ),
                    child: Row(
                      children: [
                        _PanelTab(
                          label: 'ALFA',
                          active: _tab == 'alfa',
                          onTap: () => setState(() => _tab = 'alfa'),
                          theme: theme,
                        ),
                        _PanelTab(
                          label: 'FILES',
                          active: _tab == 'files',
                          onTap: () => setState(() => _tab = 'files'),
                          theme: theme,
                        ),
                        _PanelTab(
                          label: 'PROJECT',
                          active: _tab == 'project',
                          onTap: () => setState(() => _tab = 'project'),
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Collapse button
                GestureDetector(
                  onTap: () => setState(() => _collapsed = true),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: Text('\u25B6', style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: theme.border, height: 1, thickness: AppTheme.borderWidth),
          // Content
          Expanded(
            child: switch (_tab) {
              'files' => const FileTree(),
              'project' => const ProjectPanel(),
              'alfa' => const AlfaPanel(),
              _ => const AlfaPanel(),
            },
          ),
        ],
      ),
    );
  }
}

class _PanelTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppTheme theme;

  const _PanelTab({required this.label, required this.active, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? theme.surfaceLight : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? theme.textPrimary : const Color(0xFF666666),
              fontSize: 10,
              fontWeight: active ? FontWeight.w500 : FontWeight.normal,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
