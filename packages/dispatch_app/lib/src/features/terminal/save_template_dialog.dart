import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';

class SaveTemplateDialog extends ConsumerStatefulWidget {
  final bool open;
  final String defaultName;
  final VoidCallback onClose;
  final void Function(String name) onSave;

  const SaveTemplateDialog({
    super.key,
    required this.open,
    required this.defaultName,
    required this.onClose,
    required this.onSave,
  });

  @override
  ConsumerState<SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends ConsumerState<SaveTemplateDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultName);
  }

  @override
  void didUpdateWidget(SaveTemplateDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      _controller.text = widget.defaultName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final theme = ref.watch(appThemeProvider);

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),
        Center(
          child: AnimatedSlide(
            offset: Offset(0, widget.open ? 0 : -0.02),
            duration: AppTheme.animDuration,
            curve: AppTheme.animCurve,
            child: AnimatedOpacity(
              opacity: widget.open ? 1.0 : 0.0,
              duration: AppTheme.animFastDuration,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(AppTheme.spacingXl),
                  decoration: theme.overlayDecoration,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Save Template',
                        style: theme.titleStyle.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        style: theme.bodyStyle,
                        decoration: InputDecoration(
                          hintText: 'Template name',
                          hintStyle: theme.dimStyle,
                          filled: true,
                          fillColor: theme.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => widget.onSave(_controller.text),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: widget.onClose,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: AppTheme.spacingSm),
                          ElevatedButton(
                            onPressed: () => widget.onSave(_controller.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.accentBlue,
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
