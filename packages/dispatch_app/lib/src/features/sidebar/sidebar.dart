import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../terminal/terminal_provider.dart';
import '../presets/quick_launch.dart';
import 'terminal_list.dart';
import 'status_bar.dart';

class Sidebar extends ConsumerWidget {
  final void Function(String command, {Map<String, String>? env}) onSpawn;

  const Sidebar({super.key, required this.onSpawn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final zenMode = ref.watch(terminalsProvider.select((s) => s.zenMode));

    if (zenMode) return const SizedBox.shrink();

    return SizedBox(
      width: AppTheme.sidebarWidth,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border(
            right: BorderSide(color: theme.border, width: AppTheme.borderWidth),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuickLaunch(onSpawn: onSpawn),
            Divider(color: theme.border, height: 1, thickness: AppTheme.borderWidth),
            const Expanded(child: TerminalList()),
            const StatusBar(),
          ],
        ),
      ),
    );
  }
}
