import 'package:drift/drift.dart';
import 'tables.dart';
import 'daos.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Presets, Settings, Notes, Tasks, VaultEntries, Templates, ProjectGroups,
    AlfaDecisions, AlfaConversations,
  ],
  daos: [
    PresetsDao, SettingsDao, NotesDao, TasksDao, VaultDao, TemplatesDao,
    AlfaDecisionsDao, AlfaConversationsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(alfaDecisions);
            await m.createTable(alfaConversations);
          }
        },
      );
}
