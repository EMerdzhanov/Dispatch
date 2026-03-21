import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/preset.dart';
import '../../core/models/template.dart';
import '../presets/presets_provider.dart';
import '../terminal/templates_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  final VoidCallback onOpenFolder;

  const WelcomeScreen({super.key, required this.onOpenFolder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsState = ref.watch(presetsProvider);
    final savedTemplates = presetsState.presets;
    final sessionTemplates = ref.watch(templatesProvider);

    return Container(
      color: AppTheme.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text(
              'Welcome to Dispatch',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            // Subtitle
            const Text(
              'Open a project folder to get started',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            // Open Folder button
            ElevatedButton(
              key: const Key('open_folder_button'),
              onPressed: onOpenFolder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Open Folder',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            // Saved templates list
            if (savedTemplates.isNotEmpty) ...[
              const SizedBox(height: 40),
              const Text(
                'Saved Templates',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              ...savedTemplates.map(
                (preset) => _TemplateRow(preset: preset, onOpenFolder: onOpenFolder),
              ),
            ],
            // Session templates (saved via Cmd+Shift+S)
            if (sessionTemplates.isNotEmpty) ...[
              const SizedBox(height: 40),
              const Text(
                'Session Templates',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              ...sessionTemplates.map(
                (template) => _SessionTemplateRow(
                  template: template,
                  onOpenFolder: onOpenFolder,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final Preset preset;
  final VoidCallback onOpenFolder;

  const _TemplateRow({required this.preset, required this.onOpenFolder});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenFolder,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.terminal, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preset.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SessionTemplateRow extends StatelessWidget {
  final Template template;
  final VoidCallback onOpenFolder;

  const _SessionTemplateRow({required this.template, required this.onOpenFolder});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenFolder,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.save_outlined, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    template.cwd,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
