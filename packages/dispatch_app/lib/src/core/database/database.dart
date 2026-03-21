import 'package:drift/drift.dart';
import 'tables.dart';
import 'daos.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Presets,
    Settings,
    Notes,
    Tasks,
    VaultEntries,
    Templates,
    ProjectGroups,
  ],
  daos: [PresetsDao, SettingsDao, NotesDao, TasksDao, VaultDao, TemplatesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
}
