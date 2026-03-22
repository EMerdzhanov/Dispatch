import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../projects/project_panel.dart';
import 'file_tree.dart';

/// Collapsible right panel containing File Tree and Tasks/Notes/Vault.
class RightPanel extends ConsumerStatefulWidget {
  const RightPanel({super.key});

  @override
  ConsumerState<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends ConsumerState<RightPanel> {
  bool _collapsed = false;
  String _tab = 'files'; // 'files' | 'project'

  @override
  Widget build(BuildContext context) {
    if (_collapsed) {
      return GestureDetector(
        onTap: () => setState(() => _collapsed = false),
        child: Container(
          width: 28,
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(left: BorderSide(color: AppTheme.border, width: AppTheme.borderWidth)),
          ),
          child: const Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                'FILES & NOTES',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 1.5),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(color: AppTheme.border, width: AppTheme.borderWidth)),
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
                      color: AppTheme.tabTrack,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppTheme.tabTrackBorder, width: 1),
                    ),
                    child: Row(
                      children: [
                        _PanelTab(
                          label: 'FILES',
                          active: _tab == 'files',
                          onTap: () => setState(() => _tab = 'files'),
                        ),
                        _PanelTab(
                          label: 'PROJECT',
                          active: _tab == 'project',
                          onTap: () => setState(() => _tab = 'project'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Collapse button
                GestureDetector(
                  onTap: () => setState(() => _collapsed = true),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: Text('\u25B6', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.border, height: 1, thickness: AppTheme.borderWidth),
          // Content
          Expanded(
            child: _tab == 'files'
                ? const FileTree()
                : const ProjectPanel(),
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

  const _PanelTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.surfaceLight : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppTheme.textPrimary : const Color(0xFF666666),
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
