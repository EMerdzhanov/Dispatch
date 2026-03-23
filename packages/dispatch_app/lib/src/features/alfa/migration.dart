import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'default_identity.dart';
import '../../persistence/auto_save.dart';

/// Migrate from Alfa v1 (sha256-hashed project files, Drift decisions) to v2
/// (slugified paths, file-based log). Only runs if old data exists and new doesn't.
Future<void> migrateFromV1(Ref ref) async {
  final base = alfaDir();

  // Migrate project knowledge files: {hash}/knowledge.md → {slugified-path}.md
  final db = ref.read(databaseProvider);

  // Read all project groups to get CWD → hash mappings
  final groups = await db.select(db.projectGroups).get();
  for (final group in groups) {
    final cwd = group.cwd;
    if (cwd == null || cwd.isEmpty) continue;

    final hash = sha256.convert(utf8.encode(cwd)).toString();
    final oldPath = '$base/projects/$hash/knowledge.md';
    final newPath = '$base/projects/${slugifyPath(cwd)}.md';

    final oldFile = File(oldPath);
    final newFile = File(newPath);

    if (await oldFile.exists() && !await newFile.exists()) {
      final content = await oldFile.readAsString();
      await writeFile(newPath, content);
    }
  }

  // Migrate decisions from Drift to log.md
  final logPath = '$base/log.md';
  final logFile = File(logPath);
  if (!await logFile.exists() || (await logFile.readAsString()).isEmpty) {
    try {
      final decisions = await db.alfaDecisionsDao.getRecent(limit: 100);
      if (decisions.isNotEmpty) {
        final entries = decisions.map((d) {
          final ts = d.createdAt.toUtc().toIso8601String();
          return '- [$ts] [${d.outcome}] ${d.summary}';
        }).join('\n');
        await writeFile(logPath, '$entries\n');
      }
    } catch (_) {
      // Table may not exist if this is a fresh install — ignore
    }
  }
}
