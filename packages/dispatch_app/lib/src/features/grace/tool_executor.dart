import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'grace_types.dart';

typedef GraceToolHandler = Future<Map<String, dynamic>> Function(
  Ref ref,
  Map<String, dynamic> params,
);

class GraceToolEntry {
  final GraceToolDefinition definition;
  final GraceToolHandler handler;
  final Duration timeout;

  const GraceToolEntry({
    required this.definition,
    required this.handler,
    this.timeout = const Duration(seconds: 5),
  });
}

class ToolExecutor {
  final Ref ref;
  final Map<String, GraceToolEntry> _tools = {};

  ToolExecutor(this.ref);

  void register(GraceToolEntry entry) {
    _tools[entry.definition.name] = entry;
  }

  void registerAll(List<GraceToolEntry> entries) {
    for (final entry in entries) {
      _tools[entry.definition.name] = entry;
    }
  }

  List<GraceToolDefinition> get definitions =>
      _tools.values.map((e) => e.definition).toList();

  Future<GraceToolResult> execute(GraceToolUse toolUse) async {
    final entry = _tools[toolUse.name];
    if (entry == null) {
      return GraceToolResult(
        toolUseId: toolUse.id,
        content: 'Unknown tool: ${toolUse.name}',
        isError: true,
      );
    }

    try {
      final result = await entry.handler(ref, toolUse.input)
          .timeout(entry.timeout);
      return GraceToolResult(
        toolUseId: toolUse.id,
        content: _encodeResult(result),
      );
    } on TimeoutException {
      return GraceToolResult(
        toolUseId: toolUse.id,
        content: 'Tool ${toolUse.name} timed out after ${entry.timeout.inSeconds}s',
        isError: true,
      );
    } catch (e) {
      return GraceToolResult(
        toolUseId: toolUse.id,
        content: 'Error: $e',
        isError: true,
      );
    }
  }

  Future<List<GraceToolResult>> executeAll(List<GraceToolUse> toolUses) {
    return Future.wait(toolUses.map(execute));
  }

  String _encodeResult(Map<String, dynamic> result) {
    try {
      return const JsonEncoder.withIndent(null).convert(result);
    } catch (_) {
      return result.toString();
    }
  }
}
