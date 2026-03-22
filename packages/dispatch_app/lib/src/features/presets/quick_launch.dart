import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'presets_provider.dart';

class QuickLaunch extends ConsumerWidget {
  final void Function(String command, {Map<String, String>? env}) onSpawn;

  const QuickLaunch({super.key, required this.onSpawn});

  Color _parseColor(String hex) {
    final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
    return Color(int.parse(cleaned, radix: 16) + 0xFF000000);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider).presets;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingXs),
            child: Text('QUICK LAUNCH', style: AppTheme.labelStyle),
          ),
          ...presets.map((preset) {
            final dotColor = _parseColor(preset.color);
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _PresetButton(
                name: preset.name,
                dotColor: dotColor,
                onTap: () => onSpawn(preset.command, env: preset.env),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PresetButton extends StatefulWidget {
  final String name;
  final Color dotColor;
  final VoidCallback onTap;

  const _PresetButton({
    required this.name,
    required this.dotColor,
    required this.onTap,
  });

  @override
  State<_PresetButton> createState() => _PresetButtonState();
}

class _PresetButtonState extends State<_PresetButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.surfaceLight : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    color: _hovered ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
