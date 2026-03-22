import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../../core/models/preset.dart';
import '../../core/models/template.dart';
import '../presets/presets_provider.dart';
import '../terminal/templates_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  final VoidCallback onOpenFolder;

  const WelcomeScreen({super.key, required this.onOpenFolder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme(ref.watch(activeThemeProvider));
    final presetsState = ref.watch(presetsProvider);
    final savedTemplates = presetsState.presets;
    final sessionTemplates = ref.watch(templatesProvider);

    return Container(
      color: theme.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient title
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [theme.accentBlue, Colors.white],
              ).createShader(bounds),
              child: const Text(
                'Welcome to Dispatch',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            // Subtitle
            Text(
              'Open a project folder to get started',
              style: theme.titleStyle.copyWith(color: theme.textSecondary),
            ),
            const SizedBox(height: 32),
            // Open Folder button with hover glow
            _OpenFolderButton(onTap: onOpenFolder, theme: theme),
            // Saved templates list
            if (savedTemplates.isNotEmpty) ...[
              const SizedBox(height: 40),
              Text(
                'SAVED TEMPLATES',
                style: theme.labelStyle,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              ...savedTemplates.map(
                (preset) => _TemplateRow(preset: preset, onOpenFolder: onOpenFolder, theme: theme),
              ),
            ],
            // Session templates (saved via Cmd+Shift+S)
            if (sessionTemplates.isNotEmpty) ...[
              const SizedBox(height: 40),
              Text(
                'SESSION TEMPLATES',
                style: theme.labelStyle,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              ...sessionTemplates.map(
                (template) => _SessionTemplateRow(
                  template: template,
                  onOpenFolder: onOpenFolder,
                  theme: theme,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OpenFolderButton extends StatefulWidget {
  final VoidCallback onTap;
  final AppTheme theme;

  const _OpenFolderButton({required this.onTap, required this.theme});

  @override
  State<_OpenFolderButton> createState() => _OpenFolderButtonState();
}

class _OpenFolderButtonState extends State<_OpenFolderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppTheme.hoverDuration,
        curve: AppTheme.animCurve,
        decoration: BoxDecoration(
          color: theme.accentBlue,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: _hovered
              ? [BoxShadow(color: theme.accentBlue.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: -4)]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('open_folder_button'),
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              child: Text(
                'Open Folder',
                style: theme.titleStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final Preset preset;
  final VoidCallback onOpenFolder;
  final AppTheme theme;

  const _TemplateRow({required this.preset, required this.onOpenFolder, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenFolder,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: AppTheme.spacingXs),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: theme.border, width: AppTheme.borderWidth),
        ),
        child: Row(
          children: [
            Icon(Icons.terminal, size: 14, color: theme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preset.name,
                style: theme.bodyStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 10, color: theme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SessionTemplateRow extends StatelessWidget {
  final Template template;
  final VoidCallback onOpenFolder;
  final AppTheme theme;

  const _SessionTemplateRow({required this.template, required this.onOpenFolder, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenFolder,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: AppTheme.spacingXs),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: theme.border, width: AppTheme.borderWidth),
        ),
        child: Row(
          children: [
            Icon(Icons.save_outlined, size: 14, color: theme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: theme.bodyStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    template.cwd,
                    style: theme.dimStyle.copyWith(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 10, color: theme.textSecondary),
          ],
        ),
      ),
    );
  }
}
