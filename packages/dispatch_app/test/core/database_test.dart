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

    test('delete preset', () async {
      final id = await db.presetsDao.insertPreset(
        name: 'Del',
        command: 'rm',
        color: '#000',
        icon: 'x',
      );
      await db.presetsDao.deletePreset(id);
      expect(await db.presetsDao.getAllPresets(), isEmpty);
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

  group('TemplatesDao', () {
    test('insert and list', () async {
      await db.templatesDao.insertTemplate(
        name: 'Dev Setup',
        cwd: '/code/foo',
        layoutJson: '{"type":"leaf","terminalId":"t1"}',
      );
      final templates = await db.templatesDao.getAllTemplates();
      expect(templates.length, 1);
      expect(templates[0].name, 'Dev Setup');
    });
  });
}
