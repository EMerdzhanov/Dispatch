import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

class _ShortcutEntry {
  final String action;
  final List<String> keys;

  const _ShortcutEntry({required this.action, required this.keys});
}

const _shortcuts = [
  _ShortcutEntry(action: 'New Terminal', keys: ['⌘', 'N']),
  _ShortcutEntry(action: 'Open Folder', keys: ['⌘', 'T']),
  _ShortcutEntry(action: 'Close Split', keys: ['⌘', 'W']),
  _ShortcutEntry(action: 'Quick Switcher', keys: ['⌘', 'K']),
  _ShortcutEntry(action: 'Command Palette', keys: ['⌘', '⇧', 'P']),
  _ShortcutEntry(action: 'Split Horizontal', keys: ['⌘', 'D']),
  _ShortcutEntry(action: 'Split Vertical', keys: ['⌘', '⇧', 'D']),
  _ShortcutEntry(action: 'Zen Mode', keys: ['⌘', '⇧', 'Z']),
  _ShortcutEntry(action: 'Settings', keys: ['⌘', ',']),
  _ShortcutEntry(action: 'Save Template', keys: ['⌘', '⇧', 'S']),
];

class ShortcutsPanel extends StatelessWidget {
  final bool open;
  final VoidCallback onClose;

  const ShortcutsPanel({
    super.key,
    required this.open,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();

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
          // Backdrop
          GestureDetector(
            onTap: onClose,
            child: Container(
              color: Colors.black54,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Panel
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 400,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Material(
                color: AppTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _shortcuts.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: AppTheme.border,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final entry = _shortcuts[index];
                          return _ShortcutRow(entry: entry);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Text(
            'Keyboard Shortcuts',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatefulWidget {
  final _ShortcutEntry entry;

  const _ShortcutRow({required this.entry});

  @override
  State<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<_ShortcutRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: _hovered ? AppTheme.surfaceLight : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.entry.action,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.entry.keys.asMap().entries.map((entry) {
                final isLast = entry.key == widget.entry.keys.length - 1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _KeyBadge(label: entry.value),
                    if (!isLast) const SizedBox(width: 4),
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

  const _KeyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 12,
          fontFamily: '.AppleSystemUIFont',
        ),
      ),
    );
  }
}
