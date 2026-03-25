// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PresetsTable extends Presets with TableInfo<$PresetsTable, Preset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PresetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandMeta = const VerificationMeta(
    'command',
  );
  @override
  late final GeneratedColumn<String> command = GeneratedColumn<String>(
    'command',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envJsonMeta = const VerificationMeta(
    'envJson',
  );
  @override
  late final GeneratedColumn<String> envJson = GeneratedColumn<String>(
    'env_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    command,
    color,
    icon,
    envJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'presets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('command')) {
      context.handle(
        _commandMeta,
        command.isAcceptableOrUnknown(data['command']!, _commandMeta),
      );
    } else if (isInserting) {
      context.missing(_commandMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('env_json')) {
      context.handle(
        _envJsonMeta,
        envJson.isAcceptableOrUnknown(data['env_json']!, _envJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Preset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      command: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      envJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}env_json'],
      ),
    );
  }

  @override
  $PresetsTable createAlias(String alias) {
    return $PresetsTable(attachedDatabase, alias);
  }
}

class Preset extends DataClass implements Insertable<Preset> {
  final int id;
  final String name;
  final String command;
  final String color;
  final String icon;
  final String? envJson;
  const Preset({
    required this.id,
    required this.name,
    required this.command,
    required this.color,
    required this.icon,
    this.envJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['command'] = Variable<String>(command);
    map['color'] = Variable<String>(color);
    map['icon'] = Variable<String>(icon);
    if (!nullToAbsent || envJson != null) {
      map['env_json'] = Variable<String>(envJson);
    }
    return map;
  }

  PresetsCompanion toCompanion(bool nullToAbsent) {
    return PresetsCompanion(
      id: Value(id),
      name: Value(name),
      command: Value(command),
      color: Value(color),
      icon: Value(icon),
      envJson: envJson == null && nullToAbsent
          ? const Value.absent()
          : Value(envJson),
    );
  }

  factory Preset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preset(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      command: serializer.fromJson<String>(json['command']),
      color: serializer.fromJson<String>(json['color']),
      icon: serializer.fromJson<String>(json['icon']),
      envJson: serializer.fromJson<String?>(json['envJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'command': serializer.toJson<String>(command),
      'color': serializer.toJson<String>(color),
      'icon': serializer.toJson<String>(icon),
      'envJson': serializer.toJson<String?>(envJson),
    };
  }

  Preset copyWith({
    int? id,
    String? name,
    String? command,
    String? color,
    String? icon,
    Value<String?> envJson = const Value.absent(),
  }) => Preset(
    id: id ?? this.id,
    name: name ?? this.name,
    command: command ?? this.command,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    envJson: envJson.present ? envJson.value : this.envJson,
  );
  Preset copyWithCompanion(PresetsCompanion data) {
    return Preset(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      command: data.command.present ? data.command.value : this.command,
      color: data.color.present ? data.color.value : this.color,
      icon: data.icon.present ? data.icon.value : this.icon,
      envJson: data.envJson.present ? data.envJson.value : this.envJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preset(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('command: $command, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('envJson: $envJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, command, color, icon, envJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preset &&
          other.id == this.id &&
          other.name == this.name &&
          other.command == this.command &&
          other.color == this.color &&
          other.icon == this.icon &&
          other.envJson == this.envJson);
}

class PresetsCompanion extends UpdateCompanion<Preset> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> command;
  final Value<String> color;
  final Value<String> icon;
  final Value<String?> envJson;
  const PresetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.command = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.envJson = const Value.absent(),
  });
  PresetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String command,
    required String color,
    required String icon,
    this.envJson = const Value.absent(),
  }) : name = Value(name),
       command = Value(command),
       color = Value(color),
       icon = Value(icon);
  static Insertable<Preset> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? command,
    Expression<String>? color,
    Expression<String>? icon,
    Expression<String>? envJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (command != null) 'command': command,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (envJson != null) 'env_json': envJson,
    });
  }

  PresetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? command,
    Value<String>? color,
    Value<String>? icon,
    Value<String?>? envJson,
  }) {
    return PresetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      envJson: envJson ?? this.envJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (command.present) {
      map['command'] = Variable<String>(command.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (envJson.present) {
      map['env_json'] = Variable<String>(envJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PresetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('command: $command, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('envJson: $envJson')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectCwdMeta = const VerificationMeta(
    'projectCwd',
  );
  @override
  late final GeneratedColumn<String> projectCwd = GeneratedColumn<String>(
    'project_cwd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectCwd,
    title,
    body,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_cwd')) {
      context.handle(
        _projectCwdMeta,
        projectCwd.isAcceptableOrUnknown(data['project_cwd']!, _projectCwdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectCwdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectCwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_cwd'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final int id;
  final String projectCwd;
  final String title;
  final String body;
  final DateTime updatedAt;
  const Note({
    required this.id,
    required this.projectCwd,
    required this.title,
    required this.body,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_cwd'] = Variable<String>(projectCwd);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      projectCwd: Value(projectCwd),
      title: Value(title),
      body: Value(body),
      updatedAt: Value(updatedAt),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<int>(json['id']),
      projectCwd: serializer.fromJson<String>(json['projectCwd']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectCwd': serializer.toJson<String>(projectCwd),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Note copyWith({
    int? id,
    String? projectCwd,
    String? title,
    String? body,
    DateTime? updatedAt,
  }) => Note(
    id: id ?? this.id,
    projectCwd: projectCwd ?? this.projectCwd,
    title: title ?? this.title,
    body: body ?? this.body,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      projectCwd: data.projectCwd.present
          ? data.projectCwd.value
          : this.projectCwd,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectCwd, title, body, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.projectCwd == this.projectCwd &&
          other.title == this.title &&
          other.body == this.body &&
          other.updatedAt == this.updatedAt);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<String> projectCwd;
  final Value<String> title;
  final Value<String> body;
  final Value<DateTime> updatedAt;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.projectCwd = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required String projectCwd,
    required String title,
    this.body = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : projectCwd = Value(projectCwd),
       title = Value(title);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<String>? projectCwd,
    Expression<String>? title,
    Expression<String>? body,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectCwd != null) 'project_cwd': projectCwd,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  NotesCompanion copyWith({
    Value<int>? id,
    Value<String>? projectCwd,
    Value<String>? title,
    Value<String>? body,
    Value<DateTime>? updatedAt,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      projectCwd: projectCwd ?? this.projectCwd,
      title: title ?? this.title,
      body: body ?? this.body,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectCwd.present) {
      map['project_cwd'] = Variable<String>(projectCwd.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectCwdMeta = const VerificationMeta(
    'projectCwd',
  );
  @override
  late final GeneratedColumn<String> projectCwd = GeneratedColumn<String>(
    'project_cwd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectCwd,
    title,
    description,
    done,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_cwd')) {
      context.handle(
        _projectCwdMeta,
        projectCwd.isAcceptableOrUnknown(data['project_cwd']!, _projectCwdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectCwdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectCwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_cwd'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final int id;
  final String projectCwd;
  final String title;
  final String description;
  final bool done;
  const Task({
    required this.id,
    required this.projectCwd,
    required this.title,
    required this.description,
    required this.done,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_cwd'] = Variable<String>(projectCwd);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['done'] = Variable<bool>(done);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      projectCwd: Value(projectCwd),
      title: Value(title),
      description: Value(description),
      done: Value(done),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<int>(json['id']),
      projectCwd: serializer.fromJson<String>(json['projectCwd']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      done: serializer.fromJson<bool>(json['done']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectCwd': serializer.toJson<String>(projectCwd),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'done': serializer.toJson<bool>(done),
    };
  }

  Task copyWith({
    int? id,
    String? projectCwd,
    String? title,
    String? description,
    bool? done,
  }) => Task(
    id: id ?? this.id,
    projectCwd: projectCwd ?? this.projectCwd,
    title: title ?? this.title,
    description: description ?? this.description,
    done: done ?? this.done,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      projectCwd: data.projectCwd.present
          ? data.projectCwd.value
          : this.projectCwd,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      done: data.done.present ? data.done.value : this.done,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('done: $done')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectCwd, title, description, done);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.projectCwd == this.projectCwd &&
          other.title == this.title &&
          other.description == this.description &&
          other.done == this.done);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<int> id;
  final Value<String> projectCwd;
  final Value<String> title;
  final Value<String> description;
  final Value<bool> done;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.projectCwd = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.done = const Value.absent(),
  });
  TasksCompanion.insert({
    this.id = const Value.absent(),
    required String projectCwd,
    required String title,
    this.description = const Value.absent(),
    this.done = const Value.absent(),
  }) : projectCwd = Value(projectCwd),
       title = Value(title);
  static Insertable<Task> custom({
    Expression<int>? id,
    Expression<String>? projectCwd,
    Expression<String>? title,
    Expression<String>? description,
    Expression<bool>? done,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectCwd != null) 'project_cwd': projectCwd,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (done != null) 'done': done,
    });
  }

  TasksCompanion copyWith({
    Value<int>? id,
    Value<String>? projectCwd,
    Value<String>? title,
    Value<String>? description,
    Value<bool>? done,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      projectCwd: projectCwd ?? this.projectCwd,
      title: title ?? this.title,
      description: description ?? this.description,
      done: done ?? this.done,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectCwd.present) {
      map['project_cwd'] = Variable<String>(projectCwd.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('done: $done')
          ..write(')'))
        .toString();
  }
}

class $VaultEntriesTable extends VaultEntries
    with TableInfo<$VaultEntriesTable, VaultEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectCwdMeta = const VerificationMeta(
    'projectCwd',
  );
  @override
  late final GeneratedColumn<String> projectCwd = GeneratedColumn<String>(
    'project_cwd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedValueMeta = const VerificationMeta(
    'encryptedValue',
  );
  @override
  late final GeneratedColumn<String> encryptedValue = GeneratedColumn<String>(
    'encrypted_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, projectCwd, label, encryptedValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_cwd')) {
      context.handle(
        _projectCwdMeta,
        projectCwd.isAcceptableOrUnknown(data['project_cwd']!, _projectCwdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectCwdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('encrypted_value')) {
      context.handle(
        _encryptedValueMeta,
        encryptedValue.isAcceptableOrUnknown(
          data['encrypted_value']!,
          _encryptedValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectCwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_cwd'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      encryptedValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_value'],
      )!,
    );
  }

  @override
  $VaultEntriesTable createAlias(String alias) {
    return $VaultEntriesTable(attachedDatabase, alias);
  }
}

class VaultEntry extends DataClass implements Insertable<VaultEntry> {
  final int id;
  final String projectCwd;
  final String label;
  final String encryptedValue;
  const VaultEntry({
    required this.id,
    required this.projectCwd,
    required this.label,
    required this.encryptedValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_cwd'] = Variable<String>(projectCwd);
    map['label'] = Variable<String>(label);
    map['encrypted_value'] = Variable<String>(encryptedValue);
    return map;
  }

  VaultEntriesCompanion toCompanion(bool nullToAbsent) {
    return VaultEntriesCompanion(
      id: Value(id),
      projectCwd: Value(projectCwd),
      label: Value(label),
      encryptedValue: Value(encryptedValue),
    );
  }

  factory VaultEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultEntry(
      id: serializer.fromJson<int>(json['id']),
      projectCwd: serializer.fromJson<String>(json['projectCwd']),
      label: serializer.fromJson<String>(json['label']),
      encryptedValue: serializer.fromJson<String>(json['encryptedValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectCwd': serializer.toJson<String>(projectCwd),
      'label': serializer.toJson<String>(label),
      'encryptedValue': serializer.toJson<String>(encryptedValue),
    };
  }

  VaultEntry copyWith({
    int? id,
    String? projectCwd,
    String? label,
    String? encryptedValue,
  }) => VaultEntry(
    id: id ?? this.id,
    projectCwd: projectCwd ?? this.projectCwd,
    label: label ?? this.label,
    encryptedValue: encryptedValue ?? this.encryptedValue,
  );
  VaultEntry copyWithCompanion(VaultEntriesCompanion data) {
    return VaultEntry(
      id: data.id.present ? data.id.value : this.id,
      projectCwd: data.projectCwd.present
          ? data.projectCwd.value
          : this.projectCwd,
      label: data.label.present ? data.label.value : this.label,
      encryptedValue: data.encryptedValue.present
          ? data.encryptedValue.value
          : this.encryptedValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultEntry(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('label: $label, ')
          ..write('encryptedValue: $encryptedValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectCwd, label, encryptedValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultEntry &&
          other.id == this.id &&
          other.projectCwd == this.projectCwd &&
          other.label == this.label &&
          other.encryptedValue == this.encryptedValue);
}

class VaultEntriesCompanion extends UpdateCompanion<VaultEntry> {
  final Value<int> id;
  final Value<String> projectCwd;
  final Value<String> label;
  final Value<String> encryptedValue;
  const VaultEntriesCompanion({
    this.id = const Value.absent(),
    this.projectCwd = const Value.absent(),
    this.label = const Value.absent(),
    this.encryptedValue = const Value.absent(),
  });
  VaultEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String projectCwd,
    required String label,
    required String encryptedValue,
  }) : projectCwd = Value(projectCwd),
       label = Value(label),
       encryptedValue = Value(encryptedValue);
  static Insertable<VaultEntry> custom({
    Expression<int>? id,
    Expression<String>? projectCwd,
    Expression<String>? label,
    Expression<String>? encryptedValue,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectCwd != null) 'project_cwd': projectCwd,
      if (label != null) 'label': label,
      if (encryptedValue != null) 'encrypted_value': encryptedValue,
    });
  }

  VaultEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? projectCwd,
    Value<String>? label,
    Value<String>? encryptedValue,
  }) {
    return VaultEntriesCompanion(
      id: id ?? this.id,
      projectCwd: projectCwd ?? this.projectCwd,
      label: label ?? this.label,
      encryptedValue: encryptedValue ?? this.encryptedValue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectCwd.present) {
      map['project_cwd'] = Variable<String>(projectCwd.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (encryptedValue.present) {
      map['encrypted_value'] = Variable<String>(encryptedValue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultEntriesCompanion(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('label: $label, ')
          ..write('encryptedValue: $encryptedValue')
          ..write(')'))
        .toString();
  }
}

class $TemplatesTable extends Templates
    with TableInfo<$TemplatesTable, Template> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cwdMeta = const VerificationMeta('cwd');
  @override
  late final GeneratedColumn<String> cwd = GeneratedColumn<String>(
    'cwd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layoutJsonMeta = const VerificationMeta(
    'layoutJson',
  );
  @override
  late final GeneratedColumn<String> layoutJson = GeneratedColumn<String>(
    'layout_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, cwd, layoutJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<Template> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cwd')) {
      context.handle(
        _cwdMeta,
        cwd.isAcceptableOrUnknown(data['cwd']!, _cwdMeta),
      );
    } else if (isInserting) {
      context.missing(_cwdMeta);
    }
    if (data.containsKey('layout_json')) {
      context.handle(
        _layoutJsonMeta,
        layoutJson.isAcceptableOrUnknown(data['layout_json']!, _layoutJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Template map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Template(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cwd'],
      )!,
      layoutJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layout_json'],
      ),
    );
  }

  @override
  $TemplatesTable createAlias(String alias) {
    return $TemplatesTable(attachedDatabase, alias);
  }
}

class Template extends DataClass implements Insertable<Template> {
  final int id;
  final String name;
  final String cwd;
  final String? layoutJson;
  const Template({
    required this.id,
    required this.name,
    required this.cwd,
    this.layoutJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['cwd'] = Variable<String>(cwd);
    if (!nullToAbsent || layoutJson != null) {
      map['layout_json'] = Variable<String>(layoutJson);
    }
    return map;
  }

  TemplatesCompanion toCompanion(bool nullToAbsent) {
    return TemplatesCompanion(
      id: Value(id),
      name: Value(name),
      cwd: Value(cwd),
      layoutJson: layoutJson == null && nullToAbsent
          ? const Value.absent()
          : Value(layoutJson),
    );
  }

  factory Template.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Template(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      cwd: serializer.fromJson<String>(json['cwd']),
      layoutJson: serializer.fromJson<String?>(json['layoutJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'cwd': serializer.toJson<String>(cwd),
      'layoutJson': serializer.toJson<String?>(layoutJson),
    };
  }

  Template copyWith({
    int? id,
    String? name,
    String? cwd,
    Value<String?> layoutJson = const Value.absent(),
  }) => Template(
    id: id ?? this.id,
    name: name ?? this.name,
    cwd: cwd ?? this.cwd,
    layoutJson: layoutJson.present ? layoutJson.value : this.layoutJson,
  );
  Template copyWithCompanion(TemplatesCompanion data) {
    return Template(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      cwd: data.cwd.present ? data.cwd.value : this.cwd,
      layoutJson: data.layoutJson.present
          ? data.layoutJson.value
          : this.layoutJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Template(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cwd: $cwd, ')
          ..write('layoutJson: $layoutJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, cwd, layoutJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Template &&
          other.id == this.id &&
          other.name == this.name &&
          other.cwd == this.cwd &&
          other.layoutJson == this.layoutJson);
}

class TemplatesCompanion extends UpdateCompanion<Template> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> cwd;
  final Value<String?> layoutJson;
  const TemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.cwd = const Value.absent(),
    this.layoutJson = const Value.absent(),
  });
  TemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String cwd,
    this.layoutJson = const Value.absent(),
  }) : name = Value(name),
       cwd = Value(cwd);
  static Insertable<Template> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? cwd,
    Expression<String>? layoutJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (cwd != null) 'cwd': cwd,
      if (layoutJson != null) 'layout_json': layoutJson,
    });
  }

  TemplatesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? cwd,
    Value<String?>? layoutJson,
  }) {
    return TemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      cwd: cwd ?? this.cwd,
      layoutJson: layoutJson ?? this.layoutJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cwd.present) {
      map['cwd'] = Variable<String>(cwd.value);
    }
    if (layoutJson.present) {
      map['layout_json'] = Variable<String>(layoutJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cwd: $cwd, ')
          ..write('layoutJson: $layoutJson')
          ..write(')'))
        .toString();
  }
}

class $ProjectGroupsTable extends ProjectGroups
    with TableInfo<$ProjectGroupsTable, ProjectGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cwdMeta = const VerificationMeta('cwd');
  @override
  late final GeneratedColumn<String> cwd = GeneratedColumn<String>(
    'cwd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, label, cwd, displayOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('cwd')) {
      context.handle(
        _cwdMeta,
        cwd.isAcceptableOrUnknown(data['cwd']!, _cwdMeta),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      cwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cwd'],
      ),
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
    );
  }

  @override
  $ProjectGroupsTable createAlias(String alias) {
    return $ProjectGroupsTable(attachedDatabase, alias);
  }
}

class ProjectGroup extends DataClass implements Insertable<ProjectGroup> {
  final int id;
  final String label;
  final String? cwd;
  final int displayOrder;
  const ProjectGroup({
    required this.id,
    required this.label,
    this.cwd,
    required this.displayOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || cwd != null) {
      map['cwd'] = Variable<String>(cwd);
    }
    map['display_order'] = Variable<int>(displayOrder);
    return map;
  }

  ProjectGroupsCompanion toCompanion(bool nullToAbsent) {
    return ProjectGroupsCompanion(
      id: Value(id),
      label: Value(label),
      cwd: cwd == null && nullToAbsent ? const Value.absent() : Value(cwd),
      displayOrder: Value(displayOrder),
    );
  }

  factory ProjectGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectGroup(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      cwd: serializer.fromJson<String?>(json['cwd']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
      'cwd': serializer.toJson<String?>(cwd),
      'displayOrder': serializer.toJson<int>(displayOrder),
    };
  }

  ProjectGroup copyWith({
    int? id,
    String? label,
    Value<String?> cwd = const Value.absent(),
    int? displayOrder,
  }) => ProjectGroup(
    id: id ?? this.id,
    label: label ?? this.label,
    cwd: cwd.present ? cwd.value : this.cwd,
    displayOrder: displayOrder ?? this.displayOrder,
  );
  ProjectGroup copyWithCompanion(ProjectGroupsCompanion data) {
    return ProjectGroup(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      cwd: data.cwd.present ? data.cwd.value : this.cwd,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectGroup(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('cwd: $cwd, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, label, cwd, displayOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectGroup &&
          other.id == this.id &&
          other.label == this.label &&
          other.cwd == this.cwd &&
          other.displayOrder == this.displayOrder);
}

class ProjectGroupsCompanion extends UpdateCompanion<ProjectGroup> {
  final Value<int> id;
  final Value<String> label;
  final Value<String?> cwd;
  final Value<int> displayOrder;
  const ProjectGroupsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.cwd = const Value.absent(),
    this.displayOrder = const Value.absent(),
  });
  ProjectGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String label,
    this.cwd = const Value.absent(),
    this.displayOrder = const Value.absent(),
  }) : label = Value(label);
  static Insertable<ProjectGroup> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? cwd,
    Expression<int>? displayOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (cwd != null) 'cwd': cwd,
      if (displayOrder != null) 'display_order': displayOrder,
    });
  }

  ProjectGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? label,
    Value<String?>? cwd,
    Value<int>? displayOrder,
  }) {
    return ProjectGroupsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      cwd: cwd ?? this.cwd,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (cwd.present) {
      map['cwd'] = Variable<String>(cwd.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectGroupsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('cwd: $cwd, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }
}

class $GraceDecisionsTable extends GraceDecisions
    with TableInfo<$GraceDecisionsTable, GraceDecision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GraceDecisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectCwdMeta = const VerificationMeta(
    'projectCwd',
  );
  @override
  late final GeneratedColumn<String> projectCwd = GeneratedColumn<String>(
    'project_cwd',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectCwd,
    summary,
    outcome,
    detail,
    tags,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alfa_decisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<GraceDecision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_cwd')) {
      context.handle(
        _projectCwdMeta,
        projectCwd.isAcceptableOrUnknown(data['project_cwd']!, _projectCwdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectCwdMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GraceDecision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GraceDecision(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectCwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_cwd'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $GraceDecisionsTable createAlias(String alias) {
    return $GraceDecisionsTable(attachedDatabase, alias);
  }
}

class GraceDecision extends DataClass implements Insertable<GraceDecision> {
  final int id;
  final String projectCwd;
  final String summary;
  final String outcome;
  final String? detail;
  final String tags;
  final DateTime createdAt;
  const GraceDecision({
    required this.id,
    required this.projectCwd,
    required this.summary,
    required this.outcome,
    this.detail,
    required this.tags,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_cwd'] = Variable<String>(projectCwd);
    map['summary'] = Variable<String>(summary);
    map['outcome'] = Variable<String>(outcome);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    map['tags'] = Variable<String>(tags);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GraceDecisionsCompanion toCompanion(bool nullToAbsent) {
    return GraceDecisionsCompanion(
      id: Value(id),
      projectCwd: Value(projectCwd),
      summary: Value(summary),
      outcome: Value(outcome),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      tags: Value(tags),
      createdAt: Value(createdAt),
    );
  }

  factory GraceDecision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GraceDecision(
      id: serializer.fromJson<int>(json['id']),
      projectCwd: serializer.fromJson<String>(json['projectCwd']),
      summary: serializer.fromJson<String>(json['summary']),
      outcome: serializer.fromJson<String>(json['outcome']),
      detail: serializer.fromJson<String?>(json['detail']),
      tags: serializer.fromJson<String>(json['tags']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectCwd': serializer.toJson<String>(projectCwd),
      'summary': serializer.toJson<String>(summary),
      'outcome': serializer.toJson<String>(outcome),
      'detail': serializer.toJson<String?>(detail),
      'tags': serializer.toJson<String>(tags),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  GraceDecision copyWith({
    int? id,
    String? projectCwd,
    String? summary,
    String? outcome,
    Value<String?> detail = const Value.absent(),
    String? tags,
    DateTime? createdAt,
  }) => GraceDecision(
    id: id ?? this.id,
    projectCwd: projectCwd ?? this.projectCwd,
    summary: summary ?? this.summary,
    outcome: outcome ?? this.outcome,
    detail: detail.present ? detail.value : this.detail,
    tags: tags ?? this.tags,
    createdAt: createdAt ?? this.createdAt,
  );
  GraceDecision copyWithCompanion(GraceDecisionsCompanion data) {
    return GraceDecision(
      id: data.id.present ? data.id.value : this.id,
      projectCwd: data.projectCwd.present
          ? data.projectCwd.value
          : this.projectCwd,
      summary: data.summary.present ? data.summary.value : this.summary,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      detail: data.detail.present ? data.detail.value : this.detail,
      tags: data.tags.present ? data.tags.value : this.tags,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GraceDecision(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('summary: $summary, ')
          ..write('outcome: $outcome, ')
          ..write('detail: $detail, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectCwd, summary, outcome, detail, tags, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GraceDecision &&
          other.id == this.id &&
          other.projectCwd == this.projectCwd &&
          other.summary == this.summary &&
          other.outcome == this.outcome &&
          other.detail == this.detail &&
          other.tags == this.tags &&
          other.createdAt == this.createdAt);
}

class GraceDecisionsCompanion extends UpdateCompanion<GraceDecision> {
  final Value<int> id;
  final Value<String> projectCwd;
  final Value<String> summary;
  final Value<String> outcome;
  final Value<String?> detail;
  final Value<String> tags;
  final Value<DateTime> createdAt;
  const GraceDecisionsCompanion({
    this.id = const Value.absent(),
    this.projectCwd = const Value.absent(),
    this.summary = const Value.absent(),
    this.outcome = const Value.absent(),
    this.detail = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  GraceDecisionsCompanion.insert({
    this.id = const Value.absent(),
    required String projectCwd,
    required String summary,
    required String outcome,
    this.detail = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : projectCwd = Value(projectCwd),
       summary = Value(summary),
       outcome = Value(outcome);
  static Insertable<GraceDecision> custom({
    Expression<int>? id,
    Expression<String>? projectCwd,
    Expression<String>? summary,
    Expression<String>? outcome,
    Expression<String>? detail,
    Expression<String>? tags,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectCwd != null) 'project_cwd': projectCwd,
      if (summary != null) 'summary': summary,
      if (outcome != null) 'outcome': outcome,
      if (detail != null) 'detail': detail,
      if (tags != null) 'tags': tags,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  GraceDecisionsCompanion copyWith({
    Value<int>? id,
    Value<String>? projectCwd,
    Value<String>? summary,
    Value<String>? outcome,
    Value<String?>? detail,
    Value<String>? tags,
    Value<DateTime>? createdAt,
  }) {
    return GraceDecisionsCompanion(
      id: id ?? this.id,
      projectCwd: projectCwd ?? this.projectCwd,
      summary: summary ?? this.summary,
      outcome: outcome ?? this.outcome,
      detail: detail ?? this.detail,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectCwd.present) {
      map['project_cwd'] = Variable<String>(projectCwd.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GraceDecisionsCompanion(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('summary: $summary, ')
          ..write('outcome: $outcome, ')
          ..write('detail: $detail, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GraceConversationsTable extends GraceConversations
    with TableInfo<$GraceConversationsTable, GraceConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GraceConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectCwdMeta = const VerificationMeta(
    'projectCwd',
  );
  @override
  late final GeneratedColumn<String> projectCwd = GeneratedColumn<String>(
    'project_cwd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toolCallsMeta = const VerificationMeta(
    'toolCalls',
  );
  @override
  late final GeneratedColumn<String> toolCalls = GeneratedColumn<String>(
    'tool_calls',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectCwd,
    role,
    content,
    toolCalls,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alfa_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<GraceConversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_cwd')) {
      context.handle(
        _projectCwdMeta,
        projectCwd.isAcceptableOrUnknown(data['project_cwd']!, _projectCwdMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('tool_calls')) {
      context.handle(
        _toolCallsMeta,
        toolCalls.isAcceptableOrUnknown(data['tool_calls']!, _toolCallsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GraceConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GraceConversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectCwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_cwd'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      toolCalls: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_calls'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $GraceConversationsTable createAlias(String alias) {
    return $GraceConversationsTable(attachedDatabase, alias);
  }
}

class GraceConversation extends DataClass
    implements Insertable<GraceConversation> {
  final int id;
  final String? projectCwd;
  final String role;
  final String content;
  final String? toolCalls;
  final DateTime createdAt;
  const GraceConversation({
    required this.id,
    this.projectCwd,
    required this.role,
    required this.content,
    this.toolCalls,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || projectCwd != null) {
      map['project_cwd'] = Variable<String>(projectCwd);
    }
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || toolCalls != null) {
      map['tool_calls'] = Variable<String>(toolCalls);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GraceConversationsCompanion toCompanion(bool nullToAbsent) {
    return GraceConversationsCompanion(
      id: Value(id),
      projectCwd: projectCwd == null && nullToAbsent
          ? const Value.absent()
          : Value(projectCwd),
      role: Value(role),
      content: Value(content),
      toolCalls: toolCalls == null && nullToAbsent
          ? const Value.absent()
          : Value(toolCalls),
      createdAt: Value(createdAt),
    );
  }

  factory GraceConversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GraceConversation(
      id: serializer.fromJson<int>(json['id']),
      projectCwd: serializer.fromJson<String?>(json['projectCwd']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      toolCalls: serializer.fromJson<String?>(json['toolCalls']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectCwd': serializer.toJson<String?>(projectCwd),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'toolCalls': serializer.toJson<String?>(toolCalls),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  GraceConversation copyWith({
    int? id,
    Value<String?> projectCwd = const Value.absent(),
    String? role,
    String? content,
    Value<String?> toolCalls = const Value.absent(),
    DateTime? createdAt,
  }) => GraceConversation(
    id: id ?? this.id,
    projectCwd: projectCwd.present ? projectCwd.value : this.projectCwd,
    role: role ?? this.role,
    content: content ?? this.content,
    toolCalls: toolCalls.present ? toolCalls.value : this.toolCalls,
    createdAt: createdAt ?? this.createdAt,
  );
  GraceConversation copyWithCompanion(GraceConversationsCompanion data) {
    return GraceConversation(
      id: data.id.present ? data.id.value : this.id,
      projectCwd: data.projectCwd.present
          ? data.projectCwd.value
          : this.projectCwd,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      toolCalls: data.toolCalls.present ? data.toolCalls.value : this.toolCalls,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GraceConversation(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('toolCalls: $toolCalls, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectCwd, role, content, toolCalls, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GraceConversation &&
          other.id == this.id &&
          other.projectCwd == this.projectCwd &&
          other.role == this.role &&
          other.content == this.content &&
          other.toolCalls == this.toolCalls &&
          other.createdAt == this.createdAt);
}

class GraceConversationsCompanion extends UpdateCompanion<GraceConversation> {
  final Value<int> id;
  final Value<String?> projectCwd;
  final Value<String> role;
  final Value<String> content;
  final Value<String?> toolCalls;
  final Value<DateTime> createdAt;
  const GraceConversationsCompanion({
    this.id = const Value.absent(),
    this.projectCwd = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.toolCalls = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  GraceConversationsCompanion.insert({
    this.id = const Value.absent(),
    this.projectCwd = const Value.absent(),
    required String role,
    required String content,
    this.toolCalls = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : role = Value(role),
       content = Value(content);
  static Insertable<GraceConversation> custom({
    Expression<int>? id,
    Expression<String>? projectCwd,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? toolCalls,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectCwd != null) 'project_cwd': projectCwd,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (toolCalls != null) 'tool_calls': toolCalls,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  GraceConversationsCompanion copyWith({
    Value<int>? id,
    Value<String?>? projectCwd,
    Value<String>? role,
    Value<String>? content,
    Value<String?>? toolCalls,
    Value<DateTime>? createdAt,
  }) {
    return GraceConversationsCompanion(
      id: id ?? this.id,
      projectCwd: projectCwd ?? this.projectCwd,
      role: role ?? this.role,
      content: content ?? this.content,
      toolCalls: toolCalls ?? this.toolCalls,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectCwd.present) {
      map['project_cwd'] = Variable<String>(projectCwd.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (toolCalls.present) {
      map['tool_calls'] = Variable<String>(toolCalls.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GraceConversationsCompanion(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('toolCalls: $toolCalls, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GraceMemoriesTable extends GraceMemories
    with TableInfo<$GraceMemoriesTable, GraceMemory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GraceMemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectCwdMeta = const VerificationMeta(
    'projectCwd',
  );
  @override
  late final GeneratedColumn<String> projectCwd = GeneratedColumn<String>(
    'project_cwd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastRetrievedAtMeta = const VerificationMeta(
    'lastRetrievedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastRetrievedAt =
      GeneratedColumn<DateTime>(
        'last_retrieved_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectCwd,
    category,
    content,
    tags,
    pinned,
    source,
    createdAt,
    lastRetrievedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'grace_memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<GraceMemory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_cwd')) {
      context.handle(
        _projectCwdMeta,
        projectCwd.isAcceptableOrUnknown(data['project_cwd']!, _projectCwdMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_retrieved_at')) {
      context.handle(
        _lastRetrievedAtMeta,
        lastRetrievedAt.isAcceptableOrUnknown(
          data['last_retrieved_at']!,
          _lastRetrievedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GraceMemory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GraceMemory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectCwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_cwd'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastRetrievedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_retrieved_at'],
      ),
    );
  }

  @override
  $GraceMemoriesTable createAlias(String alias) {
    return $GraceMemoriesTable(attachedDatabase, alias);
  }
}

class GraceMemory extends DataClass implements Insertable<GraceMemory> {
  final int id;
  final String? projectCwd;
  final String category;
  final String content;
  final String tags;
  final bool pinned;
  final String source;
  final DateTime createdAt;
  final DateTime? lastRetrievedAt;
  const GraceMemory({
    required this.id,
    this.projectCwd,
    required this.category,
    required this.content,
    required this.tags,
    required this.pinned,
    required this.source,
    required this.createdAt,
    this.lastRetrievedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || projectCwd != null) {
      map['project_cwd'] = Variable<String>(projectCwd);
    }
    map['category'] = Variable<String>(category);
    map['content'] = Variable<String>(content);
    map['tags'] = Variable<String>(tags);
    map['pinned'] = Variable<bool>(pinned);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastRetrievedAt != null) {
      map['last_retrieved_at'] = Variable<DateTime>(lastRetrievedAt);
    }
    return map;
  }

  GraceMemoriesCompanion toCompanion(bool nullToAbsent) {
    return GraceMemoriesCompanion(
      id: Value(id),
      projectCwd: projectCwd == null && nullToAbsent
          ? const Value.absent()
          : Value(projectCwd),
      category: Value(category),
      content: Value(content),
      tags: Value(tags),
      pinned: Value(pinned),
      source: Value(source),
      createdAt: Value(createdAt),
      lastRetrievedAt: lastRetrievedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRetrievedAt),
    );
  }

  factory GraceMemory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GraceMemory(
      id: serializer.fromJson<int>(json['id']),
      projectCwd: serializer.fromJson<String?>(json['projectCwd']),
      category: serializer.fromJson<String>(json['category']),
      content: serializer.fromJson<String>(json['content']),
      tags: serializer.fromJson<String>(json['tags']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastRetrievedAt: serializer.fromJson<DateTime?>(json['lastRetrievedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectCwd': serializer.toJson<String?>(projectCwd),
      'category': serializer.toJson<String>(category),
      'content': serializer.toJson<String>(content),
      'tags': serializer.toJson<String>(tags),
      'pinned': serializer.toJson<bool>(pinned),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastRetrievedAt': serializer.toJson<DateTime?>(lastRetrievedAt),
    };
  }

  GraceMemory copyWith({
    int? id,
    Value<String?> projectCwd = const Value.absent(),
    String? category,
    String? content,
    String? tags,
    bool? pinned,
    String? source,
    DateTime? createdAt,
    Value<DateTime?> lastRetrievedAt = const Value.absent(),
  }) => GraceMemory(
    id: id ?? this.id,
    projectCwd: projectCwd.present ? projectCwd.value : this.projectCwd,
    category: category ?? this.category,
    content: content ?? this.content,
    tags: tags ?? this.tags,
    pinned: pinned ?? this.pinned,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    lastRetrievedAt: lastRetrievedAt.present
        ? lastRetrievedAt.value
        : this.lastRetrievedAt,
  );
  GraceMemory copyWithCompanion(GraceMemoriesCompanion data) {
    return GraceMemory(
      id: data.id.present ? data.id.value : this.id,
      projectCwd: data.projectCwd.present
          ? data.projectCwd.value
          : this.projectCwd,
      category: data.category.present ? data.category.value : this.category,
      content: data.content.present ? data.content.value : this.content,
      tags: data.tags.present ? data.tags.value : this.tags,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastRetrievedAt: data.lastRetrievedAt.present
          ? data.lastRetrievedAt.value
          : this.lastRetrievedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GraceMemory(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('category: $category, ')
          ..write('content: $content, ')
          ..write('tags: $tags, ')
          ..write('pinned: $pinned, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastRetrievedAt: $lastRetrievedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectCwd,
    category,
    content,
    tags,
    pinned,
    source,
    createdAt,
    lastRetrievedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GraceMemory &&
          other.id == this.id &&
          other.projectCwd == this.projectCwd &&
          other.category == this.category &&
          other.content == this.content &&
          other.tags == this.tags &&
          other.pinned == this.pinned &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.lastRetrievedAt == this.lastRetrievedAt);
}

class GraceMemoriesCompanion extends UpdateCompanion<GraceMemory> {
  final Value<int> id;
  final Value<String?> projectCwd;
  final Value<String> category;
  final Value<String> content;
  final Value<String> tags;
  final Value<bool> pinned;
  final Value<String> source;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastRetrievedAt;
  const GraceMemoriesCompanion({
    this.id = const Value.absent(),
    this.projectCwd = const Value.absent(),
    this.category = const Value.absent(),
    this.content = const Value.absent(),
    this.tags = const Value.absent(),
    this.pinned = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastRetrievedAt = const Value.absent(),
  });
  GraceMemoriesCompanion.insert({
    this.id = const Value.absent(),
    this.projectCwd = const Value.absent(),
    required String category,
    required String content,
    this.tags = const Value.absent(),
    this.pinned = const Value.absent(),
    required String source,
    this.createdAt = const Value.absent(),
    this.lastRetrievedAt = const Value.absent(),
  }) : category = Value(category),
       content = Value(content),
       source = Value(source);
  static Insertable<GraceMemory> custom({
    Expression<int>? id,
    Expression<String>? projectCwd,
    Expression<String>? category,
    Expression<String>? content,
    Expression<String>? tags,
    Expression<bool>? pinned,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastRetrievedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectCwd != null) 'project_cwd': projectCwd,
      if (category != null) 'category': category,
      if (content != null) 'content': content,
      if (tags != null) 'tags': tags,
      if (pinned != null) 'pinned': pinned,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (lastRetrievedAt != null) 'last_retrieved_at': lastRetrievedAt,
    });
  }

  GraceMemoriesCompanion copyWith({
    Value<int>? id,
    Value<String?>? projectCwd,
    Value<String>? category,
    Value<String>? content,
    Value<String>? tags,
    Value<bool>? pinned,
    Value<String>? source,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastRetrievedAt,
  }) {
    return GraceMemoriesCompanion(
      id: id ?? this.id,
      projectCwd: projectCwd ?? this.projectCwd,
      category: category ?? this.category,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      pinned: pinned ?? this.pinned,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      lastRetrievedAt: lastRetrievedAt ?? this.lastRetrievedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectCwd.present) {
      map['project_cwd'] = Variable<String>(projectCwd.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastRetrievedAt.present) {
      map['last_retrieved_at'] = Variable<DateTime>(lastRetrievedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GraceMemoriesCompanion(')
          ..write('id: $id, ')
          ..write('projectCwd: $projectCwd, ')
          ..write('category: $category, ')
          ..write('content: $content, ')
          ..write('tags: $tags, ')
          ..write('pinned: $pinned, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastRetrievedAt: $lastRetrievedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PresetsTable presets = $PresetsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $VaultEntriesTable vaultEntries = $VaultEntriesTable(this);
  late final $TemplatesTable templates = $TemplatesTable(this);
  late final $ProjectGroupsTable projectGroups = $ProjectGroupsTable(this);
  late final $GraceDecisionsTable graceDecisions = $GraceDecisionsTable(this);
  late final $GraceConversationsTable graceConversations =
      $GraceConversationsTable(this);
  late final $GraceMemoriesTable graceMemories = $GraceMemoriesTable(this);
  late final PresetsDao presetsDao = PresetsDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final NotesDao notesDao = NotesDao(this as AppDatabase);
  late final TasksDao tasksDao = TasksDao(this as AppDatabase);
  late final VaultDao vaultDao = VaultDao(this as AppDatabase);
  late final TemplatesDao templatesDao = TemplatesDao(this as AppDatabase);
  late final GraceDecisionsDao graceDecisionsDao = GraceDecisionsDao(
    this as AppDatabase,
  );
  late final GraceConversationsDao graceConversationsDao =
      GraceConversationsDao(this as AppDatabase);
  late final GraceMemoriesDao graceMemoriesDao = GraceMemoriesDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    presets,
    settings,
    notes,
    tasks,
    vaultEntries,
    templates,
    projectGroups,
    graceDecisions,
    graceConversations,
    graceMemories,
  ];
}

typedef $$PresetsTableCreateCompanionBuilder =
    PresetsCompanion Function({
      Value<int> id,
      required String name,
      required String command,
      required String color,
      required String icon,
      Value<String?> envJson,
    });
typedef $$PresetsTableUpdateCompanionBuilder =
    PresetsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> command,
      Value<String> color,
      Value<String> icon,
      Value<String?> envJson,
    });

class $$PresetsTableFilterComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envJson => $composableBuilder(
    column: $table.envJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PresetsTableOrderingComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envJson => $composableBuilder(
    column: $table.envJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PresetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get command =>
      $composableBuilder(column: $table.command, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get envJson =>
      $composableBuilder(column: $table.envJson, builder: (column) => column);
}

class $$PresetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PresetsTable,
          Preset,
          $$PresetsTableFilterComposer,
          $$PresetsTableOrderingComposer,
          $$PresetsTableAnnotationComposer,
          $$PresetsTableCreateCompanionBuilder,
          $$PresetsTableUpdateCompanionBuilder,
          (Preset, BaseReferences<_$AppDatabase, $PresetsTable, Preset>),
          Preset,
          PrefetchHooks Function()
        > {
  $$PresetsTableTableManager(_$AppDatabase db, $PresetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PresetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PresetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PresetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> command = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String?> envJson = const Value.absent(),
              }) => PresetsCompanion(
                id: id,
                name: name,
                command: command,
                color: color,
                icon: icon,
                envJson: envJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String command,
                required String color,
                required String icon,
                Value<String?> envJson = const Value.absent(),
              }) => PresetsCompanion.insert(
                id: id,
                name: name,
                command: command,
                color: color,
                icon: icon,
                envJson: envJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PresetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PresetsTable,
      Preset,
      $$PresetsTableFilterComposer,
      $$PresetsTableOrderingComposer,
      $$PresetsTableAnnotationComposer,
      $$PresetsTableCreateCompanionBuilder,
      $$PresetsTableUpdateCompanionBuilder,
      (Preset, BaseReferences<_$AppDatabase, $PresetsTable, Preset>),
      Preset,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      required String projectCwd,
      required String title,
      Value<String> body,
      Value<DateTime> updatedAt,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      Value<String> projectCwd,
      Value<String> title,
      Value<String> body,
      Value<DateTime> updatedAt,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> projectCwd = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                projectCwd: projectCwd,
                title: title,
                body: body,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String projectCwd,
                required String title,
                Value<String> body = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                projectCwd: projectCwd,
                title: title,
                body: body,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      Value<int> id,
      required String projectCwd,
      required String title,
      Value<String> description,
      Value<bool> done,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<int> id,
      Value<String> projectCwd,
      Value<String> title,
      Value<String> description,
      Value<bool> done,
    });

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
          Task,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> projectCwd = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<bool> done = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                projectCwd: projectCwd,
                title: title,
                description: description,
                done: done,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String projectCwd,
                required String title,
                Value<String> description = const Value.absent(),
                Value<bool> done = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                projectCwd: projectCwd,
                title: title,
                description: description,
                done: done,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
      Task,
      PrefetchHooks Function()
    >;
typedef $$VaultEntriesTableCreateCompanionBuilder =
    VaultEntriesCompanion Function({
      Value<int> id,
      required String projectCwd,
      required String label,
      required String encryptedValue,
    });
typedef $$VaultEntriesTableUpdateCompanionBuilder =
    VaultEntriesCompanion Function({
      Value<int> id,
      Value<String> projectCwd,
      Value<String> label,
      Value<String> encryptedValue,
    });

class $$VaultEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $VaultEntriesTable> {
  $$VaultEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedValue => $composableBuilder(
    column: $table.encryptedValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultEntriesTable> {
  $$VaultEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedValue => $composableBuilder(
    column: $table.encryptedValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultEntriesTable> {
  $$VaultEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get encryptedValue => $composableBuilder(
    column: $table.encryptedValue,
    builder: (column) => column,
  );
}

class $$VaultEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultEntriesTable,
          VaultEntry,
          $$VaultEntriesTableFilterComposer,
          $$VaultEntriesTableOrderingComposer,
          $$VaultEntriesTableAnnotationComposer,
          $$VaultEntriesTableCreateCompanionBuilder,
          $$VaultEntriesTableUpdateCompanionBuilder,
          (
            VaultEntry,
            BaseReferences<_$AppDatabase, $VaultEntriesTable, VaultEntry>,
          ),
          VaultEntry,
          PrefetchHooks Function()
        > {
  $$VaultEntriesTableTableManager(_$AppDatabase db, $VaultEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> projectCwd = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> encryptedValue = const Value.absent(),
              }) => VaultEntriesCompanion(
                id: id,
                projectCwd: projectCwd,
                label: label,
                encryptedValue: encryptedValue,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String projectCwd,
                required String label,
                required String encryptedValue,
              }) => VaultEntriesCompanion.insert(
                id: id,
                projectCwd: projectCwd,
                label: label,
                encryptedValue: encryptedValue,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultEntriesTable,
      VaultEntry,
      $$VaultEntriesTableFilterComposer,
      $$VaultEntriesTableOrderingComposer,
      $$VaultEntriesTableAnnotationComposer,
      $$VaultEntriesTableCreateCompanionBuilder,
      $$VaultEntriesTableUpdateCompanionBuilder,
      (
        VaultEntry,
        BaseReferences<_$AppDatabase, $VaultEntriesTable, VaultEntry>,
      ),
      VaultEntry,
      PrefetchHooks Function()
    >;
typedef $$TemplatesTableCreateCompanionBuilder =
    TemplatesCompanion Function({
      Value<int> id,
      required String name,
      required String cwd,
      Value<String?> layoutJson,
    });
typedef $$TemplatesTableUpdateCompanionBuilder =
    TemplatesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> cwd,
      Value<String?> layoutJson,
    });

class $$TemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cwd => $composableBuilder(
    column: $table.cwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layoutJson => $composableBuilder(
    column: $table.layoutJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cwd => $composableBuilder(
    column: $table.cwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layoutJson => $composableBuilder(
    column: $table.layoutJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cwd =>
      $composableBuilder(column: $table.cwd, builder: (column) => column);

  GeneratedColumn<String> get layoutJson => $composableBuilder(
    column: $table.layoutJson,
    builder: (column) => column,
  );
}

class $$TemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TemplatesTable,
          Template,
          $$TemplatesTableFilterComposer,
          $$TemplatesTableOrderingComposer,
          $$TemplatesTableAnnotationComposer,
          $$TemplatesTableCreateCompanionBuilder,
          $$TemplatesTableUpdateCompanionBuilder,
          (Template, BaseReferences<_$AppDatabase, $TemplatesTable, Template>),
          Template,
          PrefetchHooks Function()
        > {
  $$TemplatesTableTableManager(_$AppDatabase db, $TemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> cwd = const Value.absent(),
                Value<String?> layoutJson = const Value.absent(),
              }) => TemplatesCompanion(
                id: id,
                name: name,
                cwd: cwd,
                layoutJson: layoutJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String cwd,
                Value<String?> layoutJson = const Value.absent(),
              }) => TemplatesCompanion.insert(
                id: id,
                name: name,
                cwd: cwd,
                layoutJson: layoutJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TemplatesTable,
      Template,
      $$TemplatesTableFilterComposer,
      $$TemplatesTableOrderingComposer,
      $$TemplatesTableAnnotationComposer,
      $$TemplatesTableCreateCompanionBuilder,
      $$TemplatesTableUpdateCompanionBuilder,
      (Template, BaseReferences<_$AppDatabase, $TemplatesTable, Template>),
      Template,
      PrefetchHooks Function()
    >;
typedef $$ProjectGroupsTableCreateCompanionBuilder =
    ProjectGroupsCompanion Function({
      Value<int> id,
      required String label,
      Value<String?> cwd,
      Value<int> displayOrder,
    });
typedef $$ProjectGroupsTableUpdateCompanionBuilder =
    ProjectGroupsCompanion Function({
      Value<int> id,
      Value<String> label,
      Value<String?> cwd,
      Value<int> displayOrder,
    });

class $$ProjectGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectGroupsTable> {
  $$ProjectGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cwd => $composableBuilder(
    column: $table.cwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectGroupsTable> {
  $$ProjectGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cwd => $composableBuilder(
    column: $table.cwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectGroupsTable> {
  $$ProjectGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get cwd =>
      $composableBuilder(column: $table.cwd, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );
}

class $$ProjectGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectGroupsTable,
          ProjectGroup,
          $$ProjectGroupsTableFilterComposer,
          $$ProjectGroupsTableOrderingComposer,
          $$ProjectGroupsTableAnnotationComposer,
          $$ProjectGroupsTableCreateCompanionBuilder,
          $$ProjectGroupsTableUpdateCompanionBuilder,
          (
            ProjectGroup,
            BaseReferences<_$AppDatabase, $ProjectGroupsTable, ProjectGroup>,
          ),
          ProjectGroup,
          PrefetchHooks Function()
        > {
  $$ProjectGroupsTableTableManager(_$AppDatabase db, $ProjectGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> cwd = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
              }) => ProjectGroupsCompanion(
                id: id,
                label: label,
                cwd: cwd,
                displayOrder: displayOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String label,
                Value<String?> cwd = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
              }) => ProjectGroupsCompanion.insert(
                id: id,
                label: label,
                cwd: cwd,
                displayOrder: displayOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectGroupsTable,
      ProjectGroup,
      $$ProjectGroupsTableFilterComposer,
      $$ProjectGroupsTableOrderingComposer,
      $$ProjectGroupsTableAnnotationComposer,
      $$ProjectGroupsTableCreateCompanionBuilder,
      $$ProjectGroupsTableUpdateCompanionBuilder,
      (
        ProjectGroup,
        BaseReferences<_$AppDatabase, $ProjectGroupsTable, ProjectGroup>,
      ),
      ProjectGroup,
      PrefetchHooks Function()
    >;
typedef $$GraceDecisionsTableCreateCompanionBuilder =
    GraceDecisionsCompanion Function({
      Value<int> id,
      required String projectCwd,
      required String summary,
      required String outcome,
      Value<String?> detail,
      Value<String> tags,
      Value<DateTime> createdAt,
    });
typedef $$GraceDecisionsTableUpdateCompanionBuilder =
    GraceDecisionsCompanion Function({
      Value<int> id,
      Value<String> projectCwd,
      Value<String> summary,
      Value<String> outcome,
      Value<String?> detail,
      Value<String> tags,
      Value<DateTime> createdAt,
    });

class $$GraceDecisionsTableFilterComposer
    extends Composer<_$AppDatabase, $GraceDecisionsTable> {
  $$GraceDecisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GraceDecisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $GraceDecisionsTable> {
  $$GraceDecisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GraceDecisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GraceDecisionsTable> {
  $$GraceDecisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$GraceDecisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GraceDecisionsTable,
          GraceDecision,
          $$GraceDecisionsTableFilterComposer,
          $$GraceDecisionsTableOrderingComposer,
          $$GraceDecisionsTableAnnotationComposer,
          $$GraceDecisionsTableCreateCompanionBuilder,
          $$GraceDecisionsTableUpdateCompanionBuilder,
          (
            GraceDecision,
            BaseReferences<_$AppDatabase, $GraceDecisionsTable, GraceDecision>,
          ),
          GraceDecision,
          PrefetchHooks Function()
        > {
  $$GraceDecisionsTableTableManager(
    _$AppDatabase db,
    $GraceDecisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GraceDecisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GraceDecisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GraceDecisionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> projectCwd = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => GraceDecisionsCompanion(
                id: id,
                projectCwd: projectCwd,
                summary: summary,
                outcome: outcome,
                detail: detail,
                tags: tags,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String projectCwd,
                required String summary,
                required String outcome,
                Value<String?> detail = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => GraceDecisionsCompanion.insert(
                id: id,
                projectCwd: projectCwd,
                summary: summary,
                outcome: outcome,
                detail: detail,
                tags: tags,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GraceDecisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GraceDecisionsTable,
      GraceDecision,
      $$GraceDecisionsTableFilterComposer,
      $$GraceDecisionsTableOrderingComposer,
      $$GraceDecisionsTableAnnotationComposer,
      $$GraceDecisionsTableCreateCompanionBuilder,
      $$GraceDecisionsTableUpdateCompanionBuilder,
      (
        GraceDecision,
        BaseReferences<_$AppDatabase, $GraceDecisionsTable, GraceDecision>,
      ),
      GraceDecision,
      PrefetchHooks Function()
    >;
typedef $$GraceConversationsTableCreateCompanionBuilder =
    GraceConversationsCompanion Function({
      Value<int> id,
      Value<String?> projectCwd,
      required String role,
      required String content,
      Value<String?> toolCalls,
      Value<DateTime> createdAt,
    });
typedef $$GraceConversationsTableUpdateCompanionBuilder =
    GraceConversationsCompanion Function({
      Value<int> id,
      Value<String?> projectCwd,
      Value<String> role,
      Value<String> content,
      Value<String?> toolCalls,
      Value<DateTime> createdAt,
    });

class $$GraceConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $GraceConversationsTable> {
  $$GraceConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolCalls => $composableBuilder(
    column: $table.toolCalls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GraceConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $GraceConversationsTable> {
  $$GraceConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolCalls => $composableBuilder(
    column: $table.toolCalls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GraceConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GraceConversationsTable> {
  $$GraceConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get toolCalls =>
      $composableBuilder(column: $table.toolCalls, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$GraceConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GraceConversationsTable,
          GraceConversation,
          $$GraceConversationsTableFilterComposer,
          $$GraceConversationsTableOrderingComposer,
          $$GraceConversationsTableAnnotationComposer,
          $$GraceConversationsTableCreateCompanionBuilder,
          $$GraceConversationsTableUpdateCompanionBuilder,
          (
            GraceConversation,
            BaseReferences<
              _$AppDatabase,
              $GraceConversationsTable,
              GraceConversation
            >,
          ),
          GraceConversation,
          PrefetchHooks Function()
        > {
  $$GraceConversationsTableTableManager(
    _$AppDatabase db,
    $GraceConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GraceConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GraceConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GraceConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> projectCwd = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> toolCalls = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => GraceConversationsCompanion(
                id: id,
                projectCwd: projectCwd,
                role: role,
                content: content,
                toolCalls: toolCalls,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> projectCwd = const Value.absent(),
                required String role,
                required String content,
                Value<String?> toolCalls = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => GraceConversationsCompanion.insert(
                id: id,
                projectCwd: projectCwd,
                role: role,
                content: content,
                toolCalls: toolCalls,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GraceConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GraceConversationsTable,
      GraceConversation,
      $$GraceConversationsTableFilterComposer,
      $$GraceConversationsTableOrderingComposer,
      $$GraceConversationsTableAnnotationComposer,
      $$GraceConversationsTableCreateCompanionBuilder,
      $$GraceConversationsTableUpdateCompanionBuilder,
      (
        GraceConversation,
        BaseReferences<
          _$AppDatabase,
          $GraceConversationsTable,
          GraceConversation
        >,
      ),
      GraceConversation,
      PrefetchHooks Function()
    >;
typedef $$GraceMemoriesTableCreateCompanionBuilder =
    GraceMemoriesCompanion Function({
      Value<int> id,
      Value<String?> projectCwd,
      required String category,
      required String content,
      Value<String> tags,
      Value<bool> pinned,
      required String source,
      Value<DateTime> createdAt,
      Value<DateTime?> lastRetrievedAt,
    });
typedef $$GraceMemoriesTableUpdateCompanionBuilder =
    GraceMemoriesCompanion Function({
      Value<int> id,
      Value<String?> projectCwd,
      Value<String> category,
      Value<String> content,
      Value<String> tags,
      Value<bool> pinned,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<DateTime?> lastRetrievedAt,
    });

class $$GraceMemoriesTableFilterComposer
    extends Composer<_$AppDatabase, $GraceMemoriesTable> {
  $$GraceMemoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRetrievedAt => $composableBuilder(
    column: $table.lastRetrievedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GraceMemoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $GraceMemoriesTable> {
  $$GraceMemoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRetrievedAt => $composableBuilder(
    column: $table.lastRetrievedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GraceMemoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GraceMemoriesTable> {
  $$GraceMemoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectCwd => $composableBuilder(
    column: $table.projectCwd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastRetrievedAt => $composableBuilder(
    column: $table.lastRetrievedAt,
    builder: (column) => column,
  );
}

class $$GraceMemoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GraceMemoriesTable,
          GraceMemory,
          $$GraceMemoriesTableFilterComposer,
          $$GraceMemoriesTableOrderingComposer,
          $$GraceMemoriesTableAnnotationComposer,
          $$GraceMemoriesTableCreateCompanionBuilder,
          $$GraceMemoriesTableUpdateCompanionBuilder,
          (
            GraceMemory,
            BaseReferences<_$AppDatabase, $GraceMemoriesTable, GraceMemory>,
          ),
          GraceMemory,
          PrefetchHooks Function()
        > {
  $$GraceMemoriesTableTableManager(_$AppDatabase db, $GraceMemoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GraceMemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GraceMemoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GraceMemoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> projectCwd = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastRetrievedAt = const Value.absent(),
              }) => GraceMemoriesCompanion(
                id: id,
                projectCwd: projectCwd,
                category: category,
                content: content,
                tags: tags,
                pinned: pinned,
                source: source,
                createdAt: createdAt,
                lastRetrievedAt: lastRetrievedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> projectCwd = const Value.absent(),
                required String category,
                required String content,
                Value<String> tags = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                required String source,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastRetrievedAt = const Value.absent(),
              }) => GraceMemoriesCompanion.insert(
                id: id,
                projectCwd: projectCwd,
                category: category,
                content: content,
                tags: tags,
                pinned: pinned,
                source: source,
                createdAt: createdAt,
                lastRetrievedAt: lastRetrievedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GraceMemoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GraceMemoriesTable,
      GraceMemory,
      $$GraceMemoriesTableFilterComposer,
      $$GraceMemoriesTableOrderingComposer,
      $$GraceMemoriesTableAnnotationComposer,
      $$GraceMemoriesTableCreateCompanionBuilder,
      $$GraceMemoriesTableUpdateCompanionBuilder,
      (
        GraceMemory,
        BaseReferences<_$AppDatabase, $GraceMemoriesTable, GraceMemory>,
      ),
      GraceMemory,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PresetsTableTableManager get presets =>
      $$PresetsTableTableManager(_db, _db.presets);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$VaultEntriesTableTableManager get vaultEntries =>
      $$VaultEntriesTableTableManager(_db, _db.vaultEntries);
  $$TemplatesTableTableManager get templates =>
      $$TemplatesTableTableManager(_db, _db.templates);
  $$ProjectGroupsTableTableManager get projectGroups =>
      $$ProjectGroupsTableTableManager(_db, _db.projectGroups);
  $$GraceDecisionsTableTableManager get graceDecisions =>
      $$GraceDecisionsTableTableManager(_db, _db.graceDecisions);
  $$GraceConversationsTableTableManager get graceConversations =>
      $$GraceConversationsTableTableManager(_db, _db.graceConversations);
  $$GraceMemoriesTableTableManager get graceMemories =>
      $$GraceMemoriesTableTableManager(_db, _db.graceMemories);
}
