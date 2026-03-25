import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:dispatch_app/src/core/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('PresetsDao', () {
    test('returns empty list on empty db', () async {
      final presets = await db.presetsDao.getAllPresets();
      expect(presets, isEmpty);
    });

    test('insert and retrieve preset', () async {
      await db.presetsDao.insertPreset(
        name: 'Test',
        command: 'echo hi',
        color: '#FF0000',
        icon: 'star',
      );
      final presets = await db.presetsDao.getAllPresets();
      expect(presets.length, 1);
      expect(presets[0].name, 'Test');
    });

});

  group('SettingsDao', () {
    test('returns null for missing key', () async {
      final val = await db.settingsDao.getValue('missing');
      expect(val, isNull);
    });

    test('set and get value', () async {
      await db.settingsDao.setValue('fontSize', '14');
      expect(await db.settingsDao.getValue('fontSize'), '14');
    });

    test('overwrite existing value', () async {
      await db.settingsDao.setValue('shell', '/bin/zsh');
      await db.settingsDao.setValue('shell', '/bin/bash');
      expect(await db.settingsDao.getValue('shell'), '/bin/bash');
    });
  });

  group('NotesDao', () {
    test('insert and query by project', () async {
      await db.notesDao.insertNote(
        projectCwd: '/code/foo',
        title: 'Note 1',
        body: 'Hello',
      );
      await db.notesDao.insertNote(
        projectCwd: '/code/bar',
        title: 'Note 2',
        body: 'World',
      );
      final fooNotes = await db.notesDao.getNotesForProject('/code/foo');
      expect(fooNotes.length, 1);
      expect(fooNotes[0].title, 'Note 1');
    });
  });

  group('TasksDao', () {
    test('insert and toggle done', () async {
      final id = await db.tasksDao.insertTask(
        projectCwd: '/code/foo',
        title: 'Fix bug',
        description: 'It is broken',
      );
      var tasks = await db.tasksDao.getTasksForProject('/code/foo');
      expect(tasks[0].done, false);
      await db.tasksDao.toggleDone(id);
      tasks = await db.tasksDao.getTasksForProject('/code/foo');
      expect(tasks[0].done, true);
    });
  });

  group('VaultDao', () {
    test('insert and retrieve', () async {
      await db.vaultDao.insertEntry(
        projectCwd: '/code/foo',
        label: 'API_KEY',
        encryptedValue: 'enc123',
      );
      final entries = await db.vaultDao.getEntriesForProject('/code/foo');
      expect(entries.length, 1);
      expect(entries[0].label, 'API_KEY');
    });
  });

  group('GraceMemoriesDao', () {
    test('insert and retrieve memory', () async {
      await db.graceMemoriesDao.insertMemory(
        GraceMemoriesCompanion.insert(
          category: 'preference',
          content: 'User prefers tabs over spaces',
          source: 'user_explicit',
          tags: Value('formatting,tabs'),
        ),
      );
      final all = await db.graceMemoriesDao.getAll();
      expect(all.length, 1);
      expect(all[0].content, 'User prefers tabs over spaces');
      expect(all[0].category, 'preference');
      expect(all[0].pinned, false);
      expect(all[0].projectCwd, isNull);
    });

    test('getPinned returns only pinned memories', () async {
      await db.graceMemoriesDao.insertMemory(
        GraceMemoriesCompanion.insert(
          category: 'preference',
          content: 'Pinned memory',
          source: 'user_explicit',
          pinned: const Value(true),
        ),
      );
      await db.graceMemoriesDao.insertMemory(
        GraceMemoriesCompanion.insert(
          category: 'decision',
          content: 'Not pinned',
          source: 'grace_suggested',
        ),
      );
      final pinned = await db.graceMemoriesDao.getPinned();
      expect(pinned.length, 1);
      expect(pinned[0].content, 'Pinned memory');
    });

    test('getCandidates filters by project scope', () async {
      await db.graceMemoriesDao.insertMemory(
        GraceMemoriesCompanion.insert(
          category: 'decision',
          content: 'Global memory',
          source: 'user_explicit',
        ),
      );
      await db.graceMemoriesDao.insertMemory(
        GraceMemoriesCompanion.insert(
          projectCwd: const Value('/code/foo'),
          category: 'decision',
          content: 'Project memory',
          source: 'user_explicit',
        ),
      );
      await db.graceMemoriesDao.insertMemory(
        GraceMemoriesCompanion.insert(
          projectCwd: const Value('/code/bar'),
          category: 'decision',
          content: 'Other project memory',
          source: 'user_explicit',
        ),
      );
      final candidates = await db.graceMemoriesDao.getCandidates('/code/foo');
      expect(candidates.length, 2);
    });

    test('findDuplicate detects existing memory', () async {
      await db.graceMemoriesDao.insertMemory(
        GraceMemoriesCompanion.insert(
          category: 'preference',
          content: 'Prefers dark mode',
          source: 'user_explicit',
        ),
      );
      final dup = await db.graceMemoriesDao.findDuplicate('Prefers dark mode', null);
      expect(dup, isNotNull);
      final noDup = await db.graceMemoriesDao.findDuplicate('Something else', null);
      expect(noDup, isNull);
    });

    test('setPinned toggles pin status', () async {
      final id = await db.graceMemoriesDao.insertMemory(
        GraceMemoriesCompanion.insert(
          category: 'workflow',
          content: 'Run tests before commit',
          source: 'user_explicit',
        ),
      );
      await db.graceMemoriesDao.setPinned(id, true);
      final pinned = await db.graceMemoriesDao.getPinned();
      expect(pinned.length, 1);
      expect(pinned[0].id, id);
    });

    test('deleteMemory removes entry', () async {
      final id = await db.graceMemoriesDao.insertMemory(
        GraceMemoriesCompanion.insert(
          category: 'context',
          content: 'To be deleted',
          source: 'user_explicit',
        ),
      );
      await db.graceMemoriesDao.deleteMemory(id);
      final all = await db.graceMemoriesDao.getAll();
      expect(all, isEmpty);
    });
  });

}
