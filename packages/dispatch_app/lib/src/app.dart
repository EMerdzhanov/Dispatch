import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';

import 'core/theme/app_theme.dart';
import 'core/shortcuts/shortcut_registry.dart';
import 'core/models/split_node.dart';
import 'features/projects/projects_provider.dart';
import 'features/projects/tab_bar.dart';
import 'features/projects/welcome_screen.dart';
import 'features/terminal/terminal_provider.dart';
import 'features/terminal/terminal_area.dart';
import 'features/sidebar/sidebar.dart';
import 'features/command_palette/command_palette.dart';
import 'features/command_palette/quick_switcher.dart';
import 'features/settings/settings_panel.dart';
import 'features/shortcuts/shortcuts_panel.dart';
import 'persistence/auto_save.dart';
import 'core/models/terminal_entry.dart';
import 'core/models/template.dart';
import 'features/terminal/save_template_dialog.dart';
import 'features/terminal/templates_provider.dart';

class DispatchApp extends ConsumerStatefulWidget {
  const DispatchApp({super.key});

  @override
  ConsumerState<DispatchApp> createState() => _DispatchAppState();
}

class _DispatchAppState extends ConsumerState<DispatchApp> {
  bool _paletteOpen = false;
  bool _searchOpen = false;
  bool _settingsOpen = false;
  bool _shortcutsOpen = false;
  bool _saveTemplateOpen = false;
  bool _loaded = false;
  int _terminalCounter = 0;

  @override
  void initState() {
    super.initState();
    // Load saved state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadSavedState(ref);
      ref.read(autoSaveProvider);
      setState(() => _loaded = true);
    });
  }

  Future<void> _handleSpawn(String command, {Map<String, String>? env}) async {
    final projectsState = ref.read(projectsProvider);
    final activeGroup = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;

    final cwd = activeGroup?.cwd ?? Platform.environment['HOME'] ?? '/';
    final groupId = activeGroup?.id ??
        ref.read(projectsProvider.notifier).findOrCreateGroup(cwd);

    // Generate a unique terminal ID
    _terminalCounter++;
    final terminalId = 'term-${DateTime.now().millisecondsSinceEpoch}-$_terminalCounter';

    // Add terminal entry — TerminalPane will spawn the PTY itself
    ref.read(terminalsProvider.notifier).addTerminal(
          groupId,
          TerminalEntry(
            id: terminalId,
            command: command,
            cwd: cwd,
            status: TerminalStatus.running,
          ),
        );
    ref.read(terminalsProvider.notifier).setActiveTerminal(terminalId);
  }

  Future<void> _handleOpenFolder() async {
    debugPrint('[App] _handleOpenFolder called');
    debugPrint(StackTrace.current.toString());
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Open Project Folder',
    );
    if (result == null) return;

    final groupId =
        ref.read(projectsProvider.notifier).findOrCreateGroup(result);
    ref.read(projectsProvider.notifier).setActiveGroup(groupId);

    // Spawn a shell in the new folder
    await _handleSpawn('\$SHELL');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final projectsState = ref.watch(projectsProvider);
    final hasGroups = projectsState.groups.isNotEmpty;

    return MaterialApp(
      title: 'Dispatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Shortcuts(
        shortcuts: AppShortcuts.bindings,
        child: Actions(
          actions: {
            NewTerminalIntent: CallbackAction<NewTerminalIntent>(
              onInvoke: (_) {
                _handleSpawn('\$SHELL');
                return null;
              },
            ),
            NewTabIntent: CallbackAction<NewTabIntent>(
              onInvoke: (_) {
                _handleOpenFolder();
                return null;
              },
            ),
            OpenSearchIntent: CallbackAction<OpenSearchIntent>(
              onInvoke: (_) {
                setState(() => _searchOpen = true);
                return null;
              },
            ),
            OpenPaletteIntent: CallbackAction<OpenPaletteIntent>(
              onInvoke: (_) {
                setState(() => _paletteOpen = true);
                return null;
              },
            ),
            SplitHorizontalIntent: CallbackAction<SplitHorizontalIntent>(
              onInvoke: (_) {
                _handleSplit(SplitDirection.horizontal);
                return null;
              },
            ),
            SplitVerticalIntent: CallbackAction<SplitVerticalIntent>(
              onInvoke: (_) {
                _handleSplit(SplitDirection.vertical);
                return null;
              },
            ),
            ClosePaneIntent: CallbackAction<ClosePaneIntent>(
              onInvoke: (_) {
                _handleClosePane();
                return null;
              },
            ),
            ToggleZenModeIntent: CallbackAction<ToggleZenModeIntent>(
              onInvoke: (_) {
                ref.read(terminalsProvider.notifier).toggleZenMode();
                return null;
              },
            ),
            OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
              onInvoke: (_) {
                setState(() => _settingsOpen = true);
                return null;
              },
            ),
            SaveTemplateIntent: CallbackAction<SaveTemplateIntent>(
              onInvoke: (_) {
                setState(() => _saveTemplateOpen = true);
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: Column(
                children: [
                  // Title bar drag region
                  const _TitleBar(),
                  // Tab bar
                  ProjectTabBar(
                    onOpenFolder: _handleOpenFolder,
                    onOpenSettings: () =>
                        setState(() => _settingsOpen = true),
                    onOpenShortcuts: () =>
                        setState(() => _shortcutsOpen = true),
                  ),
                  // Main content
                  Expanded(
                    child: hasGroups
                        ? Row(
                            children: [
                              Sidebar(
                                onSpawn: (cmd, {env}) =>
                                    _handleSpawn(cmd, env: env),
                              ),
                              const Expanded(child: TerminalArea()),
                            ],
                          )
                        : WelcomeScreen(onOpenFolder: _handleOpenFolder),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            if (_paletteOpen)
              CommandPalette(
                open: true,
                onClose: () => setState(() => _paletteOpen = false),
                onSpawn: (cmd, {env}) {
                  _handleSpawn(cmd, env: env);
                  setState(() => _paletteOpen = false);
                },
              ),
            if (_searchOpen)
              QuickSwitcher(
                open: true,
                onClose: () => setState(() => _searchOpen = false),
              ),
            if (_settingsOpen)
              SettingsPanel(
                open: true,
                onClose: () => setState(() => _settingsOpen = false),
              ),
            if (_shortcutsOpen)
              ShortcutsPanel(
                open: true,
                onClose: () => setState(() => _shortcutsOpen = false),
              ),
            if (_saveTemplateOpen)
              SaveTemplateDialog(
                open: true,
                defaultName: _activeGroupLabel(),
                onClose: () => setState(() => _saveTemplateOpen = false),
                onSave: _handleSaveTemplate,
              ),
          ],
        );
      },
    );
  }

  String _activeGroupLabel() {
    final projectsState = ref.read(projectsProvider);
    final activeGroup = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;
    return activeGroup?.label ?? 'Untitled';
  }

  void _handleSaveTemplate(String name) {
    final projectsState = ref.read(projectsProvider);
    final activeGroup = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;
    if (activeGroup == null) return;

    final template = Template(
      name: name.isNotEmpty ? name : activeGroup.label,
      cwd: activeGroup.cwd ?? '/',
      layout: activeGroup.splitLayout,
    );
    ref.read(templatesProvider.notifier).addTemplate(template);
    setState(() => _saveTemplateOpen = false);
  }

  void _handleSplit(SplitDirection direction) {
    final projectsState = ref.read(projectsProvider);
    final group = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;
    if (group == null || group.terminalIds.length < 2) return;
    final layout = SplitNode.buildEqualSplit(group.terminalIds, direction);
    ref.read(projectsProvider.notifier).setGroupSplitLayout(group.id, layout);
  }

  void _handleClosePane() {
    final projectsState = ref.read(projectsProvider);
    final group = projectsState.groups
        .where((g) => g.id == projectsState.activeGroupId)
        .firstOrNull;
    if (group?.splitLayout != null) {
      ref
          .read(projectsProvider.notifier)
          .setGroupSplitLayout(group!.id, null);
    }
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 38,
        color: AppTheme.background,
        padding: const EdgeInsets.symmetric(horizontal: 80),
        child: Row(
          children: [
            Text(
              '\u2318K Search  \u2318N New',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            const Spacer(),
            Text(
              'Dispatch',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const Spacer(),
            const SizedBox(width: 120), // balance
          ],
        ),
      ),
    );
  }
}
