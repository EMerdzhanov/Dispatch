import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';
import '../core/models/preset.dart' as preset_model;
import '../features/presets/presets_provider.dart';
import '../features/projects/projects_provider.dart';
import '../features/settings/settings_provider.dart';

/// Provider for the database instance.
/// Override in main.dart with the real database before running the app:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     databaseProvider.overrideWithValue(await openDatabase()),
///   ],
///   child: const MyApp(),
/// );
/// ```
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden');
});

/// Watches Riverpod state and debounces writes to SQLite (2-second window).
///
/// Register this provider early in the widget tree (e.g. in app.dart) so
/// the listeners are active for the lifetime of the app:
///
/// ```dart
/// // Inside a ConsumerWidget build:
/// ref.watch(autoSaveProvider);
/// ```
class AutoSaveNotifier extends Notifier<void> {
  Timer? _debounce;

  @override
  void build() {
    ref.listen(projectsProvider, (_, __) => _scheduleSave());
    ref.listen(presetsProvider, (_, __) => _scheduleSave());
    ref.listen(settingsProvider, (_, __) => _scheduleSave());
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _save);
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);

    await _saveSettings(db);
    await _savePresets(db);
    await _saveProjectGroups(db);
  }

  Future<void> _saveSettings(AppDatabase db) async {
    final settings = ref.read(settingsProvider);
    await db.settingsDao.setValue('shell', settings.shell);
    await db.settingsDao.setValue('fontFamily', settings.fontFamily);
    await db.settingsDao.setValue('fontSize', settings.fontSize.toString());
    await db.settingsDao.setValue('lineHeight', settings.lineHeight.toString());
    await db.settingsDao
        .setValue('scanInterval', settings.scanInterval.toString());
    await db.settingsDao.setValue(
        'notificationsEnabled', settings.notificationsEnabled.toString());
    await db.settingsDao
        .setValue('soundEnabled', settings.soundEnabled.toString());
    await db.settingsDao
        .setValue('screenshotFolder', settings.screenshotFolder);
  }

  Future<void> _savePresets(AppDatabase db) async {
    final presets = ref.read(presetsProvider).presets;

    // Clear all existing presets and re-insert the current list.
    await db.delete(db.presets).go();

    for (final preset in presets) {
      await db.presetsDao.insertPreset(
        name: preset.name,
        command: preset.command,
        color: preset.color,
        icon: preset.icon,
        envJson: preset.env != null ? jsonEncode(preset.env) : null,
      );
    }
  }

  Future<void> _saveProjectGroups(AppDatabase db) async {
    final groups = ref.read(projectsProvider).groups;

    // Clear all existing project groups and re-insert in current order.
    await db.delete(db.projectGroups).go();

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      await db.into(db.projectGroups).insert(
            ProjectGroupsCompanion.insert(
              label: group.label,
              cwd: Value(group.cwd),
              displayOrder: Value(i),
            ),
          );
    }
  }
}

final autoSaveProvider =
    NotifierProvider<AutoSaveNotifier, void>(AutoSaveNotifier.new);

// ---------------------------------------------------------------------------
// Startup hydration
// ---------------------------------------------------------------------------

/// Loads persisted state from SQLite and hydrates the Riverpod providers.
///
/// Call this once at startup, after the database has been opened and the
/// [ProviderScope] is available:
///
/// ```dart
/// // In main.dart, inside a ProviderScope consumer or via a ref:
/// await loadSavedState(ref);
/// ```
///
/// Terminal sessions are intentionally excluded — they are ephemeral and die
/// with the process.
Future<void> loadSavedState(WidgetRef ref) async {
  final db = ref.read(databaseProvider);

  await _loadSettings(db, ref);
  await _loadPresets(db, ref);
  await _loadProjectGroups(db, ref);
}

Future<void> _loadSettings(AppDatabase db, WidgetRef ref) async {
  final shell = await db.settingsDao.getValue('shell');
  final fontFamily = await db.settingsDao.getValue('fontFamily');
  final fontSize = await db.settingsDao.getValue('fontSize');
  final lineHeight = await db.settingsDao.getValue('lineHeight');
  final scanInterval = await db.settingsDao.getValue('scanInterval');
  final notificationsEnabled =
      await db.settingsDao.getValue('notificationsEnabled');
  final soundEnabled = await db.settingsDao.getValue('soundEnabled');
  final screenshotFolder = await db.settingsDao.getValue('screenshotFolder');

  // Only hydrate if at least one setting was previously saved.
  if (shell == null &&
      fontFamily == null &&
      fontSize == null &&
      screenshotFolder == null) {
    return;
  }

  ref.read(settingsProvider.notifier).update(
        shell: shell,
        fontFamily: fontFamily,
        fontSize: fontSize != null ? double.tryParse(fontSize) : null,
        lineHeight: lineHeight != null ? double.tryParse(lineHeight) : null,
        scanInterval: scanInterval != null ? int.tryParse(scanInterval) : null,
        notificationsEnabled: notificationsEnabled != null
            ? notificationsEnabled == 'true'
            : null,
        soundEnabled: soundEnabled != null ? soundEnabled == 'true' : null,
        screenshotFolder: screenshotFolder,
      );
}

Future<void> _loadPresets(AppDatabase db, WidgetRef ref) async {
  final savedPresets = await db.presetsDao.getAllPresets();
  if (savedPresets.isEmpty) return;

  final presets = savedPresets.map((row) {
    Map<String, String>? env;
    if (row.envJson != null) {
      try {
        final decoded = jsonDecode(row.envJson!) as Map<String, dynamic>;
        env = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        // Malformed JSON — skip the env map for this preset.
      }
    }
    return preset_model.Preset(
      name: row.name,
      command: row.command,
      color: row.color,
      icon: row.icon,
      env: env,
    );
  }).toList();

  ref.read(presetsProvider.notifier).setPresets(presets);
}

Future<void> _loadProjectGroups(AppDatabase db, WidgetRef ref) async {
  final rows = await (db.select(db.projectGroups)
        ..orderBy([(t) => OrderingTerm.asc(t.displayOrder)]))
      .get();

  if (rows.isEmpty) return;

  for (final row in rows) {
    ref.read(projectsProvider.notifier).addGroup(row.cwd, row.label);
  }
}
