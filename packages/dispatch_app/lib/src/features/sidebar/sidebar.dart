import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../terminal/terminal_provider.dart';
import '../presets/quick_launch.dart';
import '../projects/project_panel.dart';
import 'terminal_list.dart';
import 'status_bar.dart';

class Sidebar extends ConsumerWidget {
  final void Function(String command, {Map<String, String>? env}) onSpawn;

  const Sidebar({super.key, required this.onSpawn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zenMode = ref.watch(terminalsProvider.select((s) => s.zenMode));

    if (zenMode) return const SizedBox.shrink();

    return SizedBox(
      width: AppTheme.sidebarWidth,
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            left: BorderSide(color: AppTheme.border, width: AppTheme.borderWidth),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top section: Quick Launch + Terminal List (~60%)
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuickLaunch(onSpawn: onSpawn),
                  const Divider(color: AppTheme.border, height: 1, thickness: AppTheme.borderWidth),
                  const Expanded(child: TerminalList()),
                  const StatusBar(),
                ],
              ),
            ),
            const Divider(color: AppTheme.border, height: 1, thickness: AppTheme.borderWidth),
            // Bottom section: Tasks / Notes / Vault (~40%)
            const Expanded(
              flex: 4,
              child: ProjectPanel(),
            ),
          ],
        ),
      ),
    );
  }
}
