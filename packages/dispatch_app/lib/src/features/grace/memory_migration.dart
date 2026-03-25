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

  await memoryFile.rename(migratedPath);

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
  var currentCategory = 'preference';

  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

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
