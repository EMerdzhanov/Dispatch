import 'package:drift/drift.dart';
import 'database.dart';
import 'tables.dart';

part 'daos.g.dart';

@DriftAccessor(tables: [Presets])
class PresetsDao extends DatabaseAccessor<AppDatabase> with _$PresetsDaoMixin {
  PresetsDao(super.db);

  Future<List<Preset>> getAllPresets() => select(presets).get();

  Future<int> insertPreset({
    required String name,
    required String command,
    required String color,
    required String icon,
    String? envJson,
  }) {
    return into(presets).insert(PresetsCompanion.insert(
      name: name,
      command: command,
      color: color,
      icon: icon,
      envJson: Value(envJson),
    ));
  }

  Future<void> deletePreset(int id) =>
      (delete(presets)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> getValue(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) {
    return into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value));
  }
}

@DriftAccessor(tables: [Notes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  Future<List<Note>> getNotesForProject(String cwd) =>
      (select(notes)
            ..where((t) => t.projectCwd.equals(cwd))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Future<int> insertNote({
    required String projectCwd,
    required String title,
    String body = '',
  }) {
    return into(notes).insert(NotesCompanion.insert(
      projectCwd: projectCwd,
      title: title,
      body: Value(body),
    ));
  }

  Future<void> updateNote(int id, {String? title, String? body}) {
    return (update(notes)..where((t) => t.id.equals(id))).write(NotesCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      body: body != null ? Value(body) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteNote(int id) =>
      (delete(notes)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  Future<List<Task>> getTasksForProject(String cwd) =>
      (select(tasks)..where((t) => t.projectCwd.equals(cwd))).get();

  Future<int> insertTask({
    required String projectCwd,
    required String title,
    String description = '',
  }) {
    return into(tasks).insert(TasksCompanion.insert(
      projectCwd: projectCwd,
      title: title,
      description: Value(description),
    ));
  }

  Future<void> toggleDone(int id) async {
    final task =
        await (select(tasks)..where((t) => t.id.equals(id))).getSingle();
    await (update(tasks)..where((t) => t.id.equals(id)))
        .write(TasksCompanion(done: Value(!task.done)));
  }

  Future<void> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [VaultEntries])
class VaultDao extends DatabaseAccessor<AppDatabase> with _$VaultDaoMixin {
  VaultDao(super.db);

  Future<List<VaultEntry>> getEntriesForProject(String cwd) =>
      (select(vaultEntries)..where((t) => t.projectCwd.equals(cwd))).get();

  Future<int> insertEntry({
    required String projectCwd,
    required String label,
    required String encryptedValue,
  }) {
    return into(vaultEntries).insert(VaultEntriesCompanion.insert(
      projectCwd: projectCwd,
      label: label,
      encryptedValue: encryptedValue,
    ));
  }

  Future<void> deleteEntry(int id) =>
      (delete(vaultEntries)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [Templates])
class TemplatesDao extends DatabaseAccessor<AppDatabase>
    with _$TemplatesDaoMixin {
  TemplatesDao(super.db);

  Future<List<Template>> getAllTemplates() => select(templates).get();

  Future<int> insertTemplate({
    required String name,
    required String cwd,
    String? layoutJson,
  }) {
    return into(templates).insert(TemplatesCompanion.insert(
      name: name,
      cwd: cwd,
      layoutJson: Value(layoutJson),
    ));
  }

  Future<void> deleteTemplate(int id) =>
      (delete(templates)..where((t) => t.id.equals(id))).go();
}
