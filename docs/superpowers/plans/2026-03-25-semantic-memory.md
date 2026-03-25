# Semantic Memory System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Grace's flat-file memory with a structured, Claude-scored semantic memory system stored in SQLite.

**Architecture:** New `GraceMemories` Drift table with DAO. Retrieval uses Claude API to score relevance of candidate memories against conversation context. Memory panel UI in the right sidebar. Migration from existing `memory.md` on first launch.

**Tech Stack:** Drift (SQLite), Flutter Riverpod, Claude Messages API, Flutter widgets

**Spec:** `docs/superpowers/specs/2026-03-25-semantic-memory-design.md`

---

## File Structure

**New files:**
| File | Responsibility |
|------|---------------|
| `lib/src/core/database/tables.dart` | Add `GraceMemories` table class (modify existing) |
| `lib/src/core/database/daos.dart` | Add `GraceMemoriesDao` (modify existing) |
| `lib/src/core/database/database.dart` | Register table + DAO, bump schema (modify existing) |
| `lib/src/features/grace/memory_retrieval.dart` | Claude relevance scoring function |
| `lib/src/features/grace/memory_migration.dart` | Flat file → DB migration |
| `lib/src/features/grace/tools/grace_memory_tools.dart` | 6 Grace-native memory tools |
| `lib/src/features/sidebar/memory_panel.dart` | Memory tab UI widget |

**Modified files:**
| File | Change |
|------|--------|
| `lib/src/features/grace/grace_orchestrator.dart` | Replace memory.md with retrieval, add behavioral instruction, call migration |
| `lib/src/features/projects/project_panel.dart` | Add Memory tab |
| `lib/src/features/mcp/tools/memory_tools.dart` | Update read_memory/update_memory to use DB |

---

### Task 1: Add GraceMemories Table

**Files:**
- Modify: `packages/dispatch_app/lib/src/core/database/tables.dart:80` (append after GraceConversations)

- [ ] **Step 1: Write the table class**

Add to the end of `tables.dart`:

```dart
class GraceMemories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectCwd => text().nullable()();
  TextColumn get category => text()(); // preference, decision, correction, context, workflow
  TextColumn get content => text()();
  TextColumn get tags => text().withDefault(const Constant(''))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  TextColumn get source => text()(); // user_explicit, grace_suggested, correction
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastRetrievedAt => dateTime().nullable()();
}
```

- [ ] **Step 2: Verify file saved correctly**

Run: `dart analyze lib/src/core/database/tables.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add packages/dispatch_app/lib/src/core/database/tables.dart
git commit -m "feat(memory): add GraceMemories table definition"
```

---

### Task 2: Add GraceMemoriesDao

**Files:**
- Modify: `packages/dispatch_app/lib/src/core/database/daos.dart:206` (append after GraceConversationsDao)

- [ ] **Step 1: Write the DAO**

Add to the end of `daos.dart` (before the closing of the file):

```dart
@DriftAccessor(tables: [GraceMemories])
class GraceMemoriesDao extends DatabaseAccessor<AppDatabase>
    with _$GraceMemoriesDaoMixin {
  GraceMemoriesDao(super.db);

  Future<List<GraceMemory>> getAll() => select(graceMemories).get();

  Future<List<GraceMemory>> getPinned() =>
      (select(graceMemories)..where((m) => m.pinned.equals(true))).get();

  Future<List<GraceMemory>> getForProject(String? cwd) {
    final q = select(graceMemories)
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]);
    if (cwd != null) {
      q.where((m) => m.projectCwd.isNull() | m.projectCwd.equals(cwd));
    } else {
      q.where((m) => m.projectCwd.isNull());
    }
    return q.get();
  }

  Future<List<GraceMemory>> getCandidates(String? cwd, {int limit = 50}) {
    final q = select(graceMemories)
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
      ..limit(limit);
    if (cwd != null) {
      q.where((m) => m.projectCwd.isNull() | m.projectCwd.equals(cwd));
    } else {
      q.where((m) => m.projectCwd.isNull());
    }
    return q.get();
  }

  Future<int> insertMemory(GraceMemoriesCompanion entry) {
    return into(graceMemories).insert(entry);
  }

  Future<void> updateMemory(int id, {String? content, String? tags, String? category}) {
    return (update(graceMemories)..where((m) => m.id.equals(id))).write(
      GraceMemoriesCompanion(
        content: content != null ? Value(content) : const Value.absent(),
        tags: tags != null ? Value(tags) : const Value.absent(),
        category: category != null ? Value(category) : const Value.absent(),
      ),
    );
  }

  Future<void> setPinned(int id, bool pinned) {
    return (update(graceMemories)..where((m) => m.id.equals(id)))
        .write(GraceMemoriesCompanion(pinned: Value(pinned)));
  }

  Future<void> touchRetrieved(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return (update(graceMemories)..where((m) => m.id.isIn(ids)))
        .write(GraceMemoriesCompanion(lastRetrievedAt: Value(DateTime.now())));
  }

  Future<void> deleteMemory(int id) =>
      (delete(graceMemories)..where((m) => m.id.equals(id))).go();

  Future<List<GraceMemory>> getStale({int thresholdDays = 90}) {
    final cutoff = DateTime.now().subtract(Duration(days: thresholdDays));
    return (select(graceMemories)
          ..where((m) =>
              m.lastRetrievedAt.isSmallerThanValue(cutoff) &
              m.lastRetrievedAt.isNotNull()))
        .get();
  }

  /// Check for existing memory with same content in same scope (duplicate prevention).
  Future<GraceMemory?> findDuplicate(String content, String? projectCwd) {
    final q = select(graceMemories)
      ..where((m) => m.content.equals(content));
    if (projectCwd != null) {
      q.where((m) => m.projectCwd.equals(projectCwd));
    } else {
      q.where((m) => m.projectCwd.isNull());
    }
    return q.getSingleOrNull();
  }
}
```

- [ ] **Step 2: Register in database.dart**

Modify `packages/dispatch_app/lib/src/core/database/database.dart`:

In the `@DriftDatabase` annotation, add `GraceMemories` to tables and `GraceMemoriesDao` to daos:

```dart
@DriftDatabase(
  tables: [
    Presets, Settings, Notes, Tasks, VaultEntries, Templates, ProjectGroups,
    GraceDecisions, GraceConversations, GraceMemories,
  ],
  daos: [
    PresetsDao, SettingsDao, NotesDao, TasksDao, VaultDao, TemplatesDao,
    GraceDecisionsDao, GraceConversationsDao, GraceMemoriesDao,
  ],
)
```

Bump schema version from `2` to `3`.

Add migration:
```dart
@override
int get schemaVersion => 3;

@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(graceDecisions);
          await m.createTable(graceConversations);
        }
        if (from < 3) {
          await m.createTable(graceMemories);
        }
      },
    );
```

- [ ] **Step 3: Regenerate Drift code**

Run: `cd packages/dispatch_app && dart run build_runner build --delete-conflicting-outputs`
Expected: `Built with build_runner` with no errors

- [ ] **Step 4: Verify build**

Run: `flutter analyze`
Expected: 0 errors

- [ ] **Step 5: Write database test**

Add to `packages/dispatch_app/test/core/database_test.dart`:

```dart
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
    // Should include global + /code/foo, not /code/bar
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
```

- [ ] **Step 6: Run tests**

Run: `cd packages/dispatch_app && flutter test test/core/database_test.dart`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add packages/dispatch_app/lib/src/core/database/ packages/dispatch_app/test/core/database_test.dart
git commit -m "feat(memory): add GraceMemoriesDao with CRUD, filtering, and duplicate detection"
```

---

### Task 3: Claude Relevance Scoring

**Files:**
- Create: `packages/dispatch_app/lib/src/features/grace/memory_retrieval.dart`

- [ ] **Step 1: Create memory_retrieval.dart**

```dart
import 'dart:convert';

import 'claude_client.dart';
import 'grace_types.dart';
import '../../core/database/database.dart';

/// Scores candidate memories for relevance using Claude.
/// Returns list of relevant memory IDs.
///
/// Falls back to all candidate IDs on any error (network, parse, timeout).
Future<List<int>> scoreMemoryRelevance(
  ClaudeClient client,
  String conversationContext,
  List<GraceMemory> candidates,
) async {
  if (candidates.isEmpty) return [];

  final memoriesJson = candidates.map((m) => {
    'id': m.id,
    'content': m.content,
    'category': m.category,
    'tags': m.tags,
  }).toList();

  final userMessage = jsonEncode({
    'context': conversationContext,
    'memories': memoriesJson,
  });

  try {
    final response = await client.sendMessage(
      systemPrompt:
          'You are a memory relevance scorer. Given a conversation context and a list '
          'of memories, return ONLY a JSON array of the IDs of memories that are relevant '
          'to this conversation. Example: [1, 5, 12]. Return [] if none are relevant. '
          'No explanation, no markdown — just the JSON array.',
      messages: [
        GraceMessage(role: MessageRole.user, text: userMessage),
      ],
      tools: [],
      maxTokens: 256,
    ).timeout(const Duration(seconds: 10));

    final text = response.text.trim();
    final ids = (jsonDecode(text) as List<dynamic>).cast<int>();
    return ids;
  } catch (_) {
    // Fallback: return all candidate IDs (noisy but functional)
    return candidates.map((m) => m.id).toList();
  }
}
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib/src/features/grace/memory_retrieval.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add packages/dispatch_app/lib/src/features/grace/memory_retrieval.dart
git commit -m "feat(memory): add Claude relevance scoring for memory retrieval"
```

---

### Task 4: Memory Migration (memory.md → DB)

**Files:**
- Create: `packages/dispatch_app/lib/src/features/grace/memory_migration.dart`

- [ ] **Step 1: Create memory_migration.dart**

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'default_identity.dart';
import '../../core/database/database.dart';
import '../../persistence/auto_save.dart';

/// Migrate memory.md to GraceMemories table.
/// Only runs once — checks for memory.md.migrated sentinel file.
Future<void> migrateMemoryToDb(Ref ref) async {
  final memoryPath = '${graceDir()}/memory.md';
  final migratedPath = '${graceDir()}/memory.md.migrated';

  final memoryFile = File(memoryPath);
  final migratedFile = File(migratedPath);

  if (!await memoryFile.exists() || await migratedFile.exists()) return;

  final content = await memoryFile.readAsString();
  if (content.trim().isEmpty) return;

  final db = ref.read(databaseProvider);
  final entries = _parseMemoryFile(content);
  var count = 0;

  for (final entry in entries) {
    // Skip duplicates
    final existing = await db.graceMemoriesDao.findDuplicate(entry.content, null);
    if (existing != null) continue;

    await db.graceMemoriesDao.insertMemory(
      GraceMemoriesCompanion.insert(
        category: entry.category,
        content: entry.content,
        source: 'user_explicit',
        tags: Value(entry.tags),
      ),
    );
    count++;
  }

  // Mark as migrated
  await memoryFile.rename(migratedPath);

  // Log migration
  final logPath = '${graceDir()}/log.md';
  final timestamp = DateTime.now().toUtc().toIso8601String();
  final logFile = File(logPath);
  final existing = await logFile.exists() ? await logFile.readAsString() : '';
  await logFile.writeAsString(
    '- [$timestamp] Migrated $count memories from memory.md to database\n$existing',
  );
}

class _ParsedEntry {
  final String content;
  final String category;
  final String tags;
  _ParsedEntry(this.content, this.category, this.tags);
}

List<_ParsedEntry> _parseMemoryFile(String content) {
  final entries = <_ParsedEntry>[];
  var currentCategory = 'preference'; // default

  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    // Section headers set category
    if (trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
      final header = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').toLowerCase();
      if (header.contains('preference') || header.contains('style') || header.contains('format')) {
        currentCategory = 'preference';
      } else if (header.contains('decision') || header.contains('architect') || header.contains('tech')) {
        currentCategory = 'decision';
      } else if (header.contains('people') || header.contains('team') || header.contains('context')) {
        currentCategory = 'context';
      } else if (header.contains('workflow') || header.contains('process')) {
        currentCategory = 'workflow';
      }
      continue;
    }

    // List items become individual memories
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      final text = trimmed.substring(2).trim();
      if (text.isEmpty) continue;
      final tags = _generateTags(text);
      entries.add(_ParsedEntry(text, currentCategory, tags));
    }
  }

  return entries;
}

String _generateTags(String text) {
  final stopWords = {'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'to', 'of',
      'and', 'in', 'for', 'on', 'with', 'at', 'by', 'from', 'or', 'not', 'that', 'this',
      'it', 'i', 'we', 'use', 'using', 'prefer', 'prefers', 'always', 'never'};
  final words = text.toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2 && !stopWords.contains(w))
      .take(3)
      .toList();
  return words.join(',');
}
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib/src/features/grace/memory_migration.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add packages/dispatch_app/lib/src/features/grace/memory_migration.dart
git commit -m "feat(memory): add memory.md to database migration"
```

---

### Task 5: Grace-Native Memory Tools

**Files:**
- Create: `packages/dispatch_app/lib/src/features/grace/tools/grace_memory_tools.dart`

- [ ] **Step 1: Create grace_memory_tools.dart**

```dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grace_types.dart';
import '../tool_executor.dart';
import '../memory_retrieval.dart';
import '../claude_client.dart';
import '../../projects/projects_provider.dart';
import '../../../persistence/auto_save.dart';
import '../../../core/database/database.dart';

List<GraceToolEntry> graceMemoryTools(ClaudeClient? client) => [
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'save_memory',
          description:
              'Save a memory to the persistent memory system. '
              'Call after the user confirms they want something remembered. '
              'Categories: preference, decision, correction, context, workflow.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'content': {'type': 'string', 'description': 'The memory to save'},
              'category': {
                'type': 'string',
                'enum': ['preference', 'decision', 'correction', 'context', 'workflow'],
              },
              'tags': {'type': 'string', 'description': 'Comma-separated lowercase tags'},
              'projectCwd': {'type': 'string', 'description': 'Project scope (null = global)'},
              'pinned': {'type': 'boolean', 'description': 'Pin to always load (default false)'},
            },
            'required': ['content', 'category'],
          },
        ),
        handler: _saveMemory,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'recall_memories',
          description: 'Retrieve memories relevant to a given context.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'context': {'type': 'string', 'description': 'Context to match memories against'},
            },
            'required': ['context'],
          },
        ),
        handler: (ref, params) => _recallMemories(ref, params, client),
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'list_memories',
          description: 'List all memories, optionally filtered by category or project.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'category': {'type': 'string', 'description': 'Filter by category'},
              'projectCwd': {'type': 'string', 'description': 'Filter by project'},
            },
          },
        ),
        handler: _listMemories,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'delete_memory',
          description: 'Delete a memory by ID.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'id': {'type': 'integer', 'description': 'Memory ID'},
            },
            'required': ['id'],
          },
        ),
        handler: _deleteMemory,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'pin_memory',
          description: 'Pin a memory so it always loads in the system prompt.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'id': {'type': 'integer', 'description': 'Memory ID'},
            },
            'required': ['id'],
          },
        ),
        handler: _pinMemory,
      ),
      GraceToolEntry(
        definition: const GraceToolDefinition(
          name: 'unpin_memory',
          description: 'Unpin a memory.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'id': {'type': 'integer', 'description': 'Memory ID'},
            },
            'required': ['id'],
          },
        ),
        handler: _unpinMemory,
      ),
    ];

String? _resolveCwd(Ref ref, Map<String, dynamic> params) {
  final explicit = params['projectCwd'] as String?;
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final state = ref.read(projectsProvider);
  final group = state.groups
      .where((g) => g.id == state.activeGroupId)
      .firstOrNull;
  return group?.cwd;
}

Future<Map<String, dynamic>> _saveMemory(Ref ref, Map<String, dynamic> params) async {
  final content = params['content'] as String? ?? '';
  final category = params['category'] as String? ?? 'preference';
  final tags = params['tags'] as String? ?? '';
  final pinned = params['pinned'] as bool? ?? false;
  final projectCwd = _resolveCwd(ref, params);

  if (content.isEmpty) throw ArgumentError('content is required');

  final db = ref.read(databaseProvider);

  // Duplicate check
  final existing = await db.graceMemoriesDao.findDuplicate(content, projectCwd);
  if (existing != null) {
    return {'id': existing.id, 'status': 'already_exists'};
  }

  final id = await db.graceMemoriesDao.insertMemory(
    GraceMemoriesCompanion.insert(
      category: category,
      content: content,
      source: 'grace_suggested',
      tags: Value(tags),
      pinned: Value(pinned),
      projectCwd: Value(projectCwd),
    ),
  );
  return {'id': id, 'status': 'saved'};
}

Future<Map<String, dynamic>> _recallMemories(
    Ref ref, Map<String, dynamic> params, ClaudeClient? client) async {
  final context = params['context'] as String? ?? '';
  final projectCwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);

  final candidates = await db.graceMemoriesDao.getCandidates(projectCwd);
  if (candidates.isEmpty) return {'memories': [], 'count': 0};

  if (client == null) {
    // No client — return all
    return {
      'memories': candidates.map((m) => _memoryToMap(m)).toList(),
      'count': candidates.length,
    };
  }

  final relevantIds = await scoreMemoryRelevance(client, context, candidates);
  final relevant = candidates.where((m) => relevantIds.contains(m.id)).toList();

  await db.graceMemoriesDao.touchRetrieved(relevantIds);

  return {
    'memories': relevant.map((m) => _memoryToMap(m)).toList(),
    'count': relevant.length,
  };
}

Future<Map<String, dynamic>> _listMemories(Ref ref, Map<String, dynamic> params) async {
  final category = params['category'] as String?;
  final projectCwd = _resolveCwd(ref, params);
  final db = ref.read(databaseProvider);

  var memories = await db.graceMemoriesDao.getForProject(projectCwd);
  if (category != null) {
    memories = memories.where((m) => m.category == category).toList();
  }

  return {
    'memories': memories.map((m) => _memoryToMap(m)).toList(),
    'count': memories.length,
  };
}

Future<Map<String, dynamic>> _deleteMemory(Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int?;
  if (id == null) throw ArgumentError('id is required');
  final db = ref.read(databaseProvider);
  await db.graceMemoriesDao.deleteMemory(id);
  return {'id': id, 'status': 'deleted'};
}

Future<Map<String, dynamic>> _pinMemory(Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int?;
  if (id == null) throw ArgumentError('id is required');
  final db = ref.read(databaseProvider);
  await db.graceMemoriesDao.setPinned(id, true);
  return {'id': id, 'status': 'pinned'};
}

Future<Map<String, dynamic>> _unpinMemory(Ref ref, Map<String, dynamic> params) async {
  final id = params['id'] as int?;
  if (id == null) throw ArgumentError('id is required');
  final db = ref.read(databaseProvider);
  await db.graceMemoriesDao.setPinned(id, false);
  return {'id': id, 'status': 'unpinned'};
}

Map<String, dynamic> _memoryToMap(GraceMemory m) => {
  'id': m.id,
  'content': m.content,
  'category': m.category,
  'tags': m.tags,
  'pinned': m.pinned,
  'projectCwd': m.projectCwd,
  'createdAt': m.createdAt.toIso8601String(),
};
```

- [ ] **Step 2: Register in orchestrator**

Modify `packages/dispatch_app/lib/src/features/grace/grace_orchestrator.dart`:

Add import:
```dart
import 'tools/grace_memory_tools.dart';
```

Do NOT register in the constructor. Register ONLY in `initialize()` after `_client` is created (after line 90 `_client = ClaudeClient(...)`):

```dart
    _tools.registerAll(graceMemoryTools(_client));
```

This ensures tools are registered exactly once with the real client instance. Tools that don't need the client (list, delete, pin, unpin) receive it but don't use it — no null-check issues.

- [ ] **Step 3: Verify analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add packages/dispatch_app/lib/src/features/grace/tools/grace_memory_tools.dart \
      packages/dispatch_app/lib/src/features/grace/grace_orchestrator.dart
git commit -m "feat(memory): add 6 Grace-native memory tools (save, recall, list, delete, pin, unpin)"
```

---

### Task 6: Integrate Memory Retrieval into System Prompt

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/grace/grace_orchestrator.dart:288-305`

- [ ] **Step 1: Add import for memory_migration.dart**

Add at top of `grace_orchestrator.dart`:
```dart
import 'memory_migration.dart';
import 'memory_retrieval.dart';
```

- [ ] **Step 2: Call migration in initialize()**

In `initialize()`, after `await _migrateOldAlfaToGrace();` (line 95), add:
```dart
    await migrateMemoryToDb(ref);
```

- [ ] **Step 3: Replace memory.md dump in _buildSystemPrompt()**

Replace lines 293-305 (the Workspace Tools instruction + memory.md dump) with:

```dart
    // Memory behavior instruction
    parts.add(
      '## Memory Behavior\n\n'
      'You have a persistent memory system and access to Tasks, Notes, and Vault panels. '
      'When you notice the user:\n'
      '- Expressing a preference ("I prefer...", "don\'t use...", "always...")\n'
      '- Making a technical decision ("we\'re going with...", "let\'s use...")\n'
      '- Correcting you ("no, it\'s actually...", "not X, Y")\n'
      '- Sharing team/people context ("John handles...", "the backend team...")\n'
      '- Describing a workflow ("before deploying, always...", "our process is...")\n\n'
      'Ask: "Want me to remember that?" Use save_memory after they confirm. '
      'If they ignore, do not re-ask about the same topic.\n\n'
      'When they mention action items, ask: "Want me to add these as tasks?" '
      'Use add_task for the Tasks panel. Prefer Tasks for trackable items over GRACE.md.',
    );

    // Pinned memories (always loaded)
    final db = ref.read(databaseProvider);
    final pinnedMemories = await db.graceMemoriesDao.getPinned();
    if (pinnedMemories.isNotEmpty) {
      final pinnedLines = pinnedMemories.map((m) =>
          '- [${m.category}] ${m.content}').join('\n');
      parts.add('## Pinned Memories\n\n$pinnedLines');
    }

    // Relevant memories (Claude-scored)
    // Safe: _buildSystemPrompt() is only called from sendMessage() which
    // already guards on _client != null (returns early if null).
    if (_client != null) {
      final candidates = await db.graceMemoriesDao.getCandidates(activeCwd);
      // Exclude pinned (already loaded) from candidates
      final unpinnedCandidates = candidates.where((m) => !m.pinned).toList();
      if (unpinnedCandidates.isNotEmpty) {
        final contextHint = activeCwd != null
            ? 'Project: ${activeCwd.split('/').last}'
            : 'General conversation';
        final relevantIds = await scoreMemoryRelevance(
            _client!, contextHint, unpinnedCandidates);
        final relevant = unpinnedCandidates
            .where((m) => relevantIds.contains(m.id))
            .toList();
        if (relevant.isNotEmpty) {
          await db.graceMemoriesDao.touchRetrieved(
              relevant.map((m) => m.id).toList());
          final relevantLines = relevant.map((m) =>
              '- [${m.category}] ${m.content}').join('\n');
          parts.add('## Relevant Memories\n\n$relevantLines');
        }
      }
    }
```

Also remove the old memory.md file creation in `initialize()` (lines 102-105):
```dart
    // DELETE these lines:
    // final memoryFile = File('${graceDir()}/memory.md');
    // if (!await memoryFile.exists()) {
    //   await writeFile(memoryFile.path, defaultMemory);
    // }
```

- [ ] **Step 4: Verify analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch_app/lib/src/features/grace/grace_orchestrator.dart
git commit -m "feat(memory): integrate semantic retrieval into Grace system prompt"
```

---

### Task 7: Update MCP Memory Tools

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/mcp/tools/memory_tools.dart:128-146`

- [ ] **Step 1: Update read_memory handler**

Replace the `_readMemory` function to read from DB:

```dart
Future<Map<String, dynamic>> _readMemory(
    Ref ref, Map<String, dynamic> params) async {
  final db = ref.read(databaseProvider);
  final pinned = await db.graceMemoriesDao.getPinned();
  final recent = await db.graceMemoriesDao.getCandidates(null, limit: 20);

  final sections = <String>[];
  if (pinned.isNotEmpty) {
    sections.add('## Pinned\n${pinned.map((m) => '- [${m.category}] ${m.content}').join('\n')}');
  }
  if (recent.isNotEmpty) {
    sections.add('## Recent\n${recent.map((m) => '- [${m.category}] ${m.content}').join('\n')}');
  }

  return {
    'content': sections.isEmpty ? 'No memories stored.' : sections.join('\n\n'),
    'pinned_count': pinned.length,
    'total_count': recent.length,
  };
}
```

Add import at top:
```dart
import '../../../persistence/auto_save.dart';
```

- [ ] **Step 2: Update update_memory handler**

Replace `_updateMemory` to insert into DB:

```dart
Future<Map<String, dynamic>> _updateMemory(
    Ref ref, Map<String, dynamic> params) async {
  final content = params['content'] as String?;
  if (content == null || content.isEmpty) {
    throw ArgumentError('content is required');
  }
  final db = ref.read(databaseProvider);

  // Check for duplicate
  final existing = await db.graceMemoriesDao.findDuplicate(content, null);
  if (existing != null) {
    return {'id': existing.id, 'status': 'already_exists'};
  }

  final id = await db.graceMemoriesDao.insertMemory(
    GraceMemoriesCompanion.insert(
      category: 'preference',
      content: content,
      source: 'user_explicit',
    ),
  );
  return {'id': id, 'status': 'saved'};
}
```

- [ ] **Step 3: Verify analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add packages/dispatch_app/lib/src/features/mcp/tools/memory_tools.dart
git commit -m "feat(memory): update MCP memory tools to use database instead of flat files"
```

---

### Task 8: Memory Panel UI

**Files:**
- Create: `packages/dispatch_app/lib/src/features/sidebar/memory_panel.dart`
- Modify: `packages/dispatch_app/lib/src/features/projects/project_panel.dart`

- [ ] **Step 1: Create memory_panel.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../projects/projects_provider.dart';
import '../../persistence/auto_save.dart';
import '../../core/database/database.dart';

final _memoryRefreshProvider = StateProvider<int>((ref) => 0);

class MemoryPanel extends ConsumerWidget {
  const MemoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    ref.watch(_memoryRefreshProvider); // rebuild trigger

    final projectState = ref.watch(projectsProvider);
    final group = projectState.groups
        .where((g) => g.id == projectState.activeGroupId)
        .firstOrNull;
    final cwd = group?.cwd;

    return FutureBuilder<_MemoryData>(
      future: _loadMemories(ref, cwd),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: Text('Loading...', style: TextStyle(color: theme.textSecondary, fontSize: 11)));
        }
        final data = snapshot.data!;
        if (data.pinned.isEmpty && data.project.isEmpty && data.global.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No memories yet.\nChat with Grace \u2014 she\'ll learn as you go.',
                style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.pinned.isNotEmpty) ...[
                _SectionHeader(label: '\u{1F4CC} Pinned (${data.pinned.length})', theme: theme),
                ...data.pinned.map((m) => _MemoryCard(memory: m, theme: theme, ref: ref)),
                const SizedBox(height: 12),
              ],
              if (data.project.isNotEmpty) ...[
                _SectionHeader(label: 'Project (${data.project.length})', theme: theme),
                ...data.project.map((m) => _MemoryCard(memory: m, theme: theme, ref: ref)),
                const SizedBox(height: 12),
              ],
              if (data.global.isNotEmpty) ...[
                _SectionHeader(label: 'Global (${data.global.length})', theme: theme),
                ...data.global.map((m) => _MemoryCard(memory: m, theme: theme, ref: ref)),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<_MemoryData> _loadMemories(WidgetRef ref, String? cwd) async {
    final db = ref.read(databaseProvider);
    final all = await db.graceMemoriesDao.getForProject(cwd);
    final pinned = all.where((m) => m.pinned).toList();
    final project = all.where((m) => !m.pinned && m.projectCwd != null).toList();
    final global = all.where((m) => !m.pinned && m.projectCwd == null).toList();
    return _MemoryData(pinned: pinned, project: project, global: global);
  }
}

class _MemoryData {
  final List<GraceMemory> pinned;
  final List<GraceMemory> project;
  final List<GraceMemory> global;
  _MemoryData({required this.pinned, required this.project, required this.global});
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final AppTheme theme;
  const _SectionHeader({required this.label, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

Color _categoryColor(String category) => switch (category) {
  'preference' => const Color(0xFF5B9BD5),
  'decision' => const Color(0xFF70AD47),
  'correction' => const Color(0xFFF4B942),
  'context' => const Color(0xFF9B59B6),
  'workflow' => const Color(0xFF1ABC9C),
  _ => const Color(0xFF89919A),
};

class _MemoryCard extends StatefulWidget {
  final GraceMemory memory;
  final AppTheme theme;
  final WidgetRef ref;
  const _MemoryCard({required this.memory, required this.theme, required this.ref});

  @override
  State<_MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<_MemoryCard> {
  bool _editing = false;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.memory.content);
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  void _refresh() => widget.ref.read(_memoryRefreshProvider.notifier).state++;

  Future<void> _togglePin() async {
    final db = widget.ref.read(databaseProvider);
    await db.graceMemoriesDao.setPinned(widget.memory.id, !widget.memory.pinned);
    _refresh();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete memory?'),
        content: Text(widget.memory.content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      final db = widget.ref.read(databaseProvider);
      await db.graceMemoriesDao.deleteMemory(widget.memory.id);
      _refresh();
    }
  }

  Future<void> _saveEdit() async {
    final newContent = _editCtrl.text.trim();
    if (newContent.isEmpty || newContent == widget.memory.content) {
      setState(() => _editing = false);
      return;
    }
    final db = widget.ref.read(databaseProvider);
    await db.graceMemoriesDao.updateMemory(widget.memory.id, content: newContent);
    setState(() => _editing = false);
    _refresh();
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final m = widget.memory;
    final catColor = _categoryColor(m.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.surfaceLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_editing)
              TextField(
                controller: _editCtrl,
                style: TextStyle(color: theme.textPrimary, fontSize: 11),
                maxLines: null,
                autofocus: true,
                onSubmitted: (_) => _saveEdit(),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              )
            else
              GestureDetector(
                onTap: () => setState(() => _editing = true),
                child: Text(
                  m.content.length > 200 ? '${m.content.substring(0, 200)}...' : m.content,
                  style: TextStyle(color: theme.textPrimary, fontSize: 11, height: 1.4),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(m.category, style: TextStyle(color: catColor, fontSize: 9, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text(_relativeTime(m.createdAt), style: TextStyle(color: theme.textSecondary, fontSize: 9)),
                const Spacer(),
                GestureDetector(
                  onTap: _togglePin,
                  child: Icon(
                    m.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 12,
                    color: m.pinned ? theme.accentBlue : theme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _delete,
                  child: Icon(Icons.close, size: 12, color: theme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add Memory tab to project_panel.dart**

Modify `packages/dispatch_app/lib/src/features/projects/project_panel.dart`:

Add import:
```dart
import '../sidebar/memory_panel.dart';
```

Add `memory` to the enum:
```dart
enum _ProjectTab { tasks, notes, vault, memory }
```

Add case to `_buildContent()`:
```dart
case _ProjectTab.memory:
  return const MemoryPanel();
```

Update the `icon` switch in `_TabBar.build()` to add the brain icon for the new tab:
```dart
final icon = switch (tab) {
  _ProjectTab.tasks => '\u2611',
  _ProjectTab.notes => '\u{1F4DD}',
  _ProjectTab.vault => '\u{1F511}',
  _ProjectTab.memory => '\u{1F9E0}',
};
```

- [ ] **Step 3: Verify analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add packages/dispatch_app/lib/src/features/sidebar/memory_panel.dart \
      packages/dispatch_app/lib/src/features/projects/project_panel.dart
git commit -m "feat(memory): add Memory panel UI with pin/edit/delete and category badges"
```

---

### Task 9: Stale Memory Check

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/grace/grace_orchestrator.dart`

- [ ] **Step 1: Add stale check at conversation start**

In `sendMessage()`, after the `_emit(GraceChatEvent.human(...))` call and before building the system prompt, add:

```dart
    // Check for stale memories (once per session)
    if (!_staleFlagged) {
      final stale = await db.graceMemoriesDao.getStale();
      if (stale.isNotEmpty) {
        _emit(GraceChatEvent.grace(
          'I have ${stale.length} old memories that haven\'t been relevant in 90+ days. '
          'You can review them in the Memory panel.',
        ));
        _staleFlagged = true;
      }
    }
```

Add field to class:
```dart
  bool _staleFlagged = false;
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add packages/dispatch_app/lib/src/features/grace/grace_orchestrator.dart
git commit -m "feat(memory): add stale memory notification at conversation start"
```

---

### Task 10: Final Integration Test

- [ ] **Step 1: Run all tests**

Run: `cd packages/dispatch_app && flutter test`
Expected: All tests pass

- [ ] **Step 2: Run full analysis**

Run: `flutter analyze`
Expected: 0 errors, 0 warnings (info-only items OK)

- [ ] **Step 3: Manual smoke test checklist**

Run the app (`flutter run -d macos`) and verify:
1. Memory tab appears in Project panel (brain icon)
2. Memory tab shows "No memories yet" when empty
3. Grace chat includes "Memory Behavior" in her responses (she offers to remember things)
4. Telling Grace "remember that I prefer dark mode" → she calls save_memory → memory appears in panel
5. Pin/unpin works in Memory panel
6. Delete with confirmation works
7. Inline edit works (click text → edit → Enter)
8. Memories grouped correctly: Pinned → Project → Global
9. If `memory.md` existed, it's migrated and renamed to `memory.md.migrated`

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat(memory): complete semantic memory system — migration, retrieval, UI, tools"
```
