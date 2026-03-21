import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'src/app.dart';
import 'src/core/database/database.dart';
import 'src/persistence/auto_save.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Initialize database
  final configDir =
      p.join(Platform.environment['HOME'] ?? '.', '.config', 'dispatch');
  final dir = Directory(configDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final dbFile = File(p.join(configDir, 'dispatch.db'));
  final database = AppDatabase(NativeDatabase(dbFile));

  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    backgroundColor: Color(0xFF0A0A1A),
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
    ],
    child: const DispatchApp(),
  ));
}
