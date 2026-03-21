import 'package:drift/drift.dart';

class Presets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get command => text()();
  TextColumn get color => text()();
  TextColumn get icon => text()();
  TextColumn get envJson => text().nullable()();
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectCwd => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectCwd => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
}

class VaultEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectCwd => text()();
  TextColumn get label => text()();
  TextColumn get encryptedValue => text()();
}

class Templates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get cwd => text()();
  TextColumn get layoutJson => text().nullable()();
}

class ProjectGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  TextColumn get cwd => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
}
