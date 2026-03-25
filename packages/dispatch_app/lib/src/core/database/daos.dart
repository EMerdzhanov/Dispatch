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

  Future<void> updateTask(int id, {String? title, String? description}) {
    return (update(tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      description: description != null ? Value(description) : const Value.absent(),
    ));
  }

  Future<void> markDone(int id) {
    return (update(tasks)..where((t) => t.id.equals(id)))
        .write(const TasksCompanion(done: Value(true)));
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

  Future<VaultEntry?> getEntryByLabel(String cwd, String label) =>
      (select(vaultEntries)
            ..where((t) => t.projectCwd.equals(cwd) & t.label.equals(label)))
          .getSingleOrNull();

  Future<void> updateEntry(int id, {required String encryptedValue}) {
    return (update(vaultEntries)..where((t) => t.id.equals(id)))
        .write(VaultEntriesCompanion(encryptedValue: Value(encryptedValue)));
  }

  Future<void> deleteEntry(int id) =>
      (delete(vaultEntries)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [Templates])
class TemplatesDao extends DatabaseAccessor<AppDatabase>
    with _$TemplatesDaoMixin {
  TemplatesDao(super.db);

}

@DriftAccessor(tables: [AlfaDecisions])
class AlfaDecisionsDao extends DatabaseAccessor<AppDatabase>
    with _$AlfaDecisionsDaoMixin {
  AlfaDecisionsDao(super.db);

  Future<List<AlfaDecision>> getForProject(String cwd) {
    return (select(alfaDecisions)
          ..where((d) => d.projectCwd.equals(cwd))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
          ..limit(50))
        .get();
  }

  Future<List<AlfaDecision>> getRecent({int limit = 10}) {
    return (select(alfaDecisions)
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)])
          ..limit(limit))
        .get();
  }

}

@DriftAccessor(tables: [AlfaConversations])
class AlfaConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$AlfaConversationsDaoMixin {
  AlfaConversationsDao(super.db);

  Future<List<AlfaConversation>> getForProject(String? cwd,
      {int limit = 100}) {
    final q = select(alfaConversations);
    if (cwd != null) {
      q.where((c) => c.projectCwd.equals(cwd));
    }
    q
      ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
      ..limit(limit);
    return q.get();
  }

  Future<int> insertMessage(AlfaConversationsCompanion entry) {
    return into(alfaConversations).insert(entry);
  }

}
