import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';

class _ShortcutEntry {
  final String action;
  final List<String> keys;

  const _ShortcutEntry({required this.action, required this.keys});
}

const _shortcuts = [
  _ShortcutEntry(action: 'New Terminal', keys: ['\u2318', 'N']),
  _ShortcutEntry(action: 'Open Folder', keys: ['\u2318', 'T']),
  _ShortcutEntry(action: 'Close Split', keys: ['\u2318', 'W']),
  _ShortcutEntry(action: 'Quick Switcher', keys: ['\u2318', 'K']),
  _ShortcutEntry(action: 'Command Palette', keys: ['\u2318', '\u21E7', 'P']),
  _ShortcutEntry(action: 'Split Horizontal', keys: ['\u2318', 'D']),
  _ShortcutEntry(action: 'Split Vertical', keys: ['\u2318', '\u21E7', 'D']),
  _ShortcutEntry(action: 'Zen Mode', keys: ['\u2318', '\u21E7', 'Z']),
  _ShortcutEntry(action: 'Settings', keys: ['\u2318', ',']),
  _ShortcutEntry(action: 'Save Template', keys: ['\u2318', '\u21E7', 'S']),
];

class ShortcutsPanel extends ConsumerWidget {
  final bool open;
  final VoidCallback onClose;

  const ShortcutsPanel({
    super.key,
    required this.open,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!open) return const SizedBox.shrink();

    final theme = AppTheme(ref.watch(activeThemeProvider));

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: false,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onClose();
        }
      },
      child: Stack(
        children: [
          // Backdrop with blur
          GestureDetector(
            onTap: onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          // Panel with slide-in
          Center(
            child: AnimatedSlide(
              offset: Offset(0, open ? 0 : -0.02),
              duration: AppTheme.animDuration,
              curve: AppTheme.animCurve,
              child: AnimatedOpacity(
                opacity: open ? 1.0 : 0.0,
                duration: AppTheme.animFastDuration,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 400,
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: theme.overlayDecoration,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(theme),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
                              itemCount: _shortcuts.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: theme.border,
                                thickness: AppTheme.borderWidth,
                                indent: AppTheme.spacingLg,
                                endIndent: AppTheme.spacingLg,
                              ),
                              itemBuilder: (context, index) {
                                final entry = _shortcuts[index];
                                return _ShortcutRow(entry: entry, theme: theme);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.border, width: AppTheme.borderWidth)),
      ),
      child: Row(
        children: [
          Text(
            'Keyboard Shortcuts',
            style: theme.titleStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Icon(
              Icons.close,
              size: 16,
              color: theme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatefulWidget {
  final _ShortcutEntry entry;
  final AppTheme theme;

  const _ShortcutRow({required this.entry, required this.theme});

  @override
  State<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<_ShortcutRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppTheme.hoverDuration,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 10),
        color: _hovered ? theme.surfaceLight : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.entry.action,
              style: theme.bodyStyle,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.entry.keys.asMap().entries.map((entry) {
                final isLast = entry.key == widget.entry.keys.length - 1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _KeyBadge(label: entry.value, theme: theme),
                    if (!isLast) const SizedBox(width: AppTheme.spacingXs),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyBadge extends StatelessWidget {
  final String label;
  final AppTheme theme;

  const _KeyBadge({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.border, width: AppTheme.borderWidth),
      ),
      child: Text(
        label,
        style: theme.bodyStyle.copyWith(fontFamily: '.AppleSystemUIFont'),
      ),
    );
  }
}
