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
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppTheme.spacingXs, bottom: AppTheme.spacingXs + 2),
            child: const Text(
              'QUICK LAUNCH',
              style: AppTheme.labelStyle,
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppTheme.spacingXs,
              crossAxisSpacing: AppTheme.spacingXs,
              childAspectRatio: 2.8,
            ),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              final dotColor = _parseColor(preset.color);
              return _PresetButton(
                name: preset.name,
                dotColor: dotColor,
                onTap: () => onSpawn(preset.command, env: preset.env),
              );
            },
          ),
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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : _hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 50),
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: AppTheme.animCurve,
            decoration: BoxDecoration(
              color: _hovered ? AppTheme.surfaceLight : AppTheme.surfaceLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: _hovered ? AppTheme.border : AppTheme.border.withValues(alpha: 0.5),
                width: AppTheme.borderWidth,
              ),
              boxShadow: _hovered
                  ? [BoxShadow(color: widget.dotColor.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: -2)]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingXs + 1),
                Expanded(
                  child: Text(
                    widget.name.toUpperCase(),
                    style: AppTheme.labelStyle.copyWith(color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
