import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../projects/project_panel.dart';
import '../grace/grace_panel.dart';
import 'file_tree.dart';

/// Collapsible right panel containing File Tree and Tasks/Notes/Vault.
class RightPanel extends ConsumerStatefulWidget {
  const RightPanel({super.key});

  @override
  ConsumerState<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends ConsumerState<RightPanel> {
  static const _minWidth = 220.0;
  static const _maxWidth = 500.0;
  static const _defaultWidth = 320.0;

  bool _collapsed = false;
  double _width = _defaultWidth;
  String _tab = 'grace'; // 'files' | 'project' | 'grace'

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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _width = (_width - details.delta.dx).clamp(_minWidth, _maxWidth);
              });
            },
            child: Container(
              width: 4,
              color: theme.border.withValues(alpha: 0.3),
            ),
          ),
        ),
        Container(
          width: _width,
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
                          label: 'GRACE',
                          active: _tab == 'grace',
                          onTap: () => setState(() => _tab = 'grace'),
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
            child: IndexedStack(
              index: switch (_tab) {
                'grace' => 0,
                'files' => 1,
                'project' => 2,
                _ => 0,
              },
              children: [
                Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (_) => const Material(
                      type: MaterialType.transparency,
                      child: GracePanel(),
                    ),
                  ),
                ),
                const FileTree(),
                const ProjectPanel(),
              ],
            ),
          ),
        ],
      ),
    ),
      ],
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
