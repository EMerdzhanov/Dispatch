import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alfa_types.dart';
import '../tool_executor.dart';
import '../../projects/projects_provider.dart';
import '../default_identity.dart';

/// A single test run result.
class TestRunResult {
  final DateTime timestamp;
  final String projectCwd;
  final String runner;
  final int passed;
  final int failed;
  final int skipped;
  final List<String> failingTests;
  final bool errored;

  TestRunResult({
    required this.timestamp,
    required this.projectCwd,
    required this.runner,
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.failingTests,
    this.errored = false,
  });

  bool get allPassed => !errored && failed == 0;
  int get total => passed + failed + skipped;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'project_cwd': projectCwd,
        'runner': runner,
        'passed': passed,
        'failed': failed,
        'skipped': skipped,
        'total': total,
        'all_passed': allPassed,
        'errored': errored,
        if (failingTests.isNotEmpty) 'failing_tests': failingTests,
      };

  factory TestRunResult.fromJson(Map<String, dynamic> json) => TestRunResult(
        timestamp: DateTime.parse(json['timestamp'] as String),
        projectCwd: json['project_cwd'] as String,
        runner: json['runner'] as String,
        passed: json['passed'] as int? ?? 0,
        failed: json['failed'] as int? ?? 0,
        skipped: json['skipped'] as int? ?? 0,
        failingTests:
            (json['failing_tests'] as List<dynamic>?)?.cast<String>() ?? [],
        errored: json['errored'] as bool? ?? false,
      );
}

class TestRegressionInfo {
  final int previousFailed;
  final int currentFailed;
  final List<String> newlyFailing;
  final DateTime previousRun;

  TestRegressionInfo({
    required this.previousFailed,
    required this.currentFailed,
    required this.newlyFailing,
    required this.previousRun,
  });
}

/// Tracks test run history per project and detects regressions.
class TestTracker {
  static const _maxHistory = 50;

  final String projectCwd;
  List<TestRunResult> _history = [];

  TestTracker(this.projectCwd);

  String get _historyKey =>
      projectCwd.replaceAll('/', '_').replaceAll(' ', '-');

  String get _historyPath =>
      '${graceDir()}/test_history/$_historyKey.json';

  Future<void> load() async {
    try {
      final file = File(_historyPath);
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      _history = raw
          .cast<Map<String, dynamic>>()
          .map(TestRunResult.fromJson)
          .toList();
    } catch (_) {
      _history = [];
    }
  }

  Future<void> _save() async {
    try {
      final file = File(_historyPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
          const JsonEncoder.withIndent('  ')
              .convert(_history.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  Future<TestRegressionInfo?> record(TestRunResult result) async {
    await load();
    _history.insert(0, result);
    if (_history.length > _maxHistory) {
      _history = _history.sublist(0, _maxHistory);
    }
    await _save();

    if (_history.length < 2) return null;
    final prev = _history[1];
    if (result.failed > prev.failed) {
      final newlyFailing = result.failingTests
          .where((t) => !prev.failingTests.contains(t))
          .toList();
      return TestRegressionInfo(
        previousFailed: prev.failed,
        currentFailed: result.failed,
        newlyFailing: newlyFailing,
        previousRun: prev.timestamp,
      );
    }
    return null;
  }

  TestRunResult? get latest => _history.isEmpty ? null : _history.first;

  Map<String, dynamic> getSummary() {
    if (_history.isEmpty) {
      return {'status': 'no_runs', 'project': projectCwd};
    }
    final last = _history.first;
    String trend = 'stable';
    if (_history.length >= 2) {
      final prev = _history[1];
      if (last.failed > prev.failed) trend = 'regressing';
      if (last.failed < prev.failed) trend = 'improving';
    }
    return {
      'project': projectCwd,
      'latest_run': last.toJson(),
      'trend': trend,
      'run_count': _history.length,
    };
  }
}

/// Detects and runs the appropriate test runner for a project.
class TestRunner {
  static Future<TestRunResult?> runTests(String cwd) async {
    final runner = await _detectRunner(cwd);
    if (runner == null) return null;
    return _execute(cwd, runner);
  }

  static Future<String?> _detectRunner(String cwd) async {
    final pkgJson = File('$cwd/package.json');
    if (await pkgJson.exists()) {
      try {
        final pkg =
            jsonDecode(await pkgJson.readAsString()) as Map<String, dynamic>;
        final scripts = pkg['scripts'] as Map<String, dynamic>?;
        if (scripts?.containsKey('test') ?? false) return 'npm test';
      } catch (_) {}
    }
    if (await File('$cwd/pubspec.yaml').exists() &&
        await Directory('$cwd/test').exists()) {
      return 'dart test';
    }
    if (await File('$cwd/pytest.ini').exists() ||
        await File('$cwd/pyproject.toml').exists()) {
      return 'pytest';
    }
    if (await File('$cwd/go.mod').exists()) return 'go test ./...';
    return null;
  }

  static Future<TestRunResult> _execute(String cwd, String runner) async {
    final parts = runner.split(' ');
    try {
      final result = await Process.run(
        parts.first,
        parts.skip(1).toList(),
        workingDirectory: cwd,
        environment: {...Platform.environment, 'CI': '1'},
      ).timeout(const Duration(minutes: 5));
      final output = '${result.stdout}\n${result.stderr}';
      return _parse(output, cwd, runner, result.exitCode);
    } on TimeoutException {
      return TestRunResult(
        timestamp: DateTime.now().toUtc(),
        projectCwd: cwd,
        runner: runner,
        passed: 0, failed: 0, skipped: 0,
        failingTests: [], errored: true,
      );
    } catch (e) {
      return TestRunResult(
        timestamp: DateTime.now().toUtc(),
        projectCwd: cwd,
        runner: runner,
        passed: 0, failed: 0, skipped: 0,
        failingTests: ['Runner error: $e'], errored: true,
      );
    }
  }

  static TestRunResult _parse(
      String output, String cwd, String runner, int exitCode) {
    int passed = 0, failed = 0, skipped = 0;
    final failingTests = <String>[];

    // Jest: "Tests: 5 passed, 1 failed, 6 total"
    final jestRe = RegExp(
        r'Tests:\s*(?:(\d+)\s*passed[,\s]*)?(?:(\d+)\s*failed[,\s]*)?(?:(\d+)\s*skipped)?',
        caseSensitive: false);
    final jm = jestRe.firstMatch(output);
    if (jm != null) {
      passed = int.tryParse(jm.group(1) ?? '') ?? 0;
      failed = int.tryParse(jm.group(2) ?? '') ?? 0;
      skipped = int.tryParse(jm.group(3) ?? '') ?? 0;
    }

    // Dart: "+5 -1 ~2"
    if (runner.startsWith('dart') || runner.startsWith('flutter')) {
      final pms = RegExp(r'\+(\d+)').allMatches(output);
      final fms = RegExp(r'-(\d+)').allMatches(output);
      final sms = RegExp(r'~(\d+)').allMatches(output);
      if (pms.isNotEmpty) passed = int.tryParse(pms.last.group(1)!) ?? 0;
      if (fms.isNotEmpty) failed = int.tryParse(fms.last.group(1)!) ?? 0;
      if (sms.isNotEmpty) skipped = int.tryParse(sms.last.group(1)!) ?? 0;
    }

    // pytest: "5 passed, 1 failed"
    if (runner.startsWith('pytest')) {
      for (final m in RegExp(r'(\d+)\s+(passed|failed|skipped)')
          .allMatches(output)) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (m.group(2) == 'passed') passed = n;
        if (m.group(2) == 'failed') failed = n;
        if (m.group(2) == 'skipped') skipped = n;
      }
    }

    // Extract failing test names
    for (final m in RegExp(r'(?:FAIL|FAILED)\s+(\S.+)', caseSensitive: false)
        .allMatches(output)) {
      final name = m.group(1)?.trim();
      if (name != null && name.length < 200) failingTests.add(name);
    }

    if (exitCode != 0 && passed == 0 && failed == 0) {
      return TestRunResult(
        timestamp: DateTime.now().toUtc(),
        projectCwd: cwd,
        runner: runner,
        passed: 0, failed: 1, skipped: 0,
        failingTests: ['Exit code $exitCode — check test output'],
      );
    }

    return TestRunResult(
      timestamp: DateTime.now().toUtc(),
      projectCwd: cwd,
      runner: runner,
      passed: passed,
      failed: failed,
      skipped: skipped,
      failingTests: failingTests.take(20).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Alfa tool entries
// ---------------------------------------------------------------------------

/// testTools() returns tools for the Alfa tool registry.
/// [trackers] is a shared map maintained by AlfaOrchestrator.
/// [onEvent] is used to emit regression alerts.
List<AlfaToolEntry> testTools(
  Map<String, TestTracker> trackers,
  void Function(AlfaChatEvent) onEvent,
) =>
    [
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'run_tests',
          description:
              'Run the test suite for the active project. '
              'Auto-detects npm test, dart test, pytest, go test. '
              'Records results in history and alerts on regressions.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {
                'type': 'string',
                'description': 'Override project directory (defaults to active)',
              },
            },
          },
        ),
        handler: (ref, params) => _runTests(ref, params, trackers, onEvent),
      ),
      AlfaToolEntry(
        definition: const AlfaToolDefinition(
          name: 'get_test_status',
          description:
              'Returns latest test run result, trend (stable/improving/regressing), '
              'and run count for the active project. '
              'Check before and after code changes to catch regressions early.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'cwd': {'type': 'string'},
            },
          },
        ),
        handler: (ref, params) => _getTestStatus(ref, params, trackers),
      ),
    ];

Future<Map<String, dynamic>> _runTests(
  Ref ref,
  Map<String, dynamic> params,
  Map<String, TestTracker> trackers,
  void Function(AlfaChatEvent) onEvent,
) async {
  final cwd = (params['cwd'] as String?) ?? _activeCwd(ref);
  if (cwd == null) return {'error': 'No active project'};

  final result = await TestRunner.runTests(cwd);
  if (result == null) {
    return {
      'status': 'no_runner',
      'message': 'No test runner detected (checked npm test, dart test, pytest, go test)',
    };
  }

  final tracker = trackers.putIfAbsent(cwd, () => TestTracker(cwd));
  final regression = await tracker.record(result);

  if (regression != null) {
    onEvent(AlfaChatEvent.alfa(
      '[Tests] Regression: ${regression.currentFailed} failing '
      '(was ${regression.previousFailed}). '
      '${regression.newlyFailing.isNotEmpty ? 'New: ${regression.newlyFailing.join(', ')}' : ''}',
    ));
  }

  return {
    ...result.toJson(),
    if (regression != null)
      'regression': {
        'newly_failing': regression.newlyFailing,
        'previous_failed': regression.previousFailed,
      },
  };
}

Future<Map<String, dynamic>> _getTestStatus(
  Ref ref,
  Map<String, dynamic> params,
  Map<String, TestTracker> trackers,
) async {
  final cwd = (params['cwd'] as String?) ?? _activeCwd(ref);
  if (cwd == null) return {'error': 'No active project'};

  final tracker = trackers.putIfAbsent(cwd, () => TestTracker(cwd));
  await tracker.load();
  return tracker.getSummary();
}

String? _activeCwd(Ref ref) {
  final state = ref.read(projectsProvider);
  return state.groups
      .where((g) => g.id == state.activeGroupId)
      .firstOrNull
      ?.cwd;
}
