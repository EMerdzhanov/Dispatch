import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_types.dart';

typedef AlfaToolHandler = Future<Map<String, dynamic>> Function(
  Ref ref,
  Map<String, dynamic> params,
);

class AlfaToolEntry {
  final AlfaToolDefinition definition;
  final AlfaToolHandler handler;
  final Duration timeout;

  const AlfaToolEntry({
    required this.definition,
    required this.handler,
    this.timeout = const Duration(seconds: 5),
  });
}

class ToolExecutor {
  final Ref ref;
  final Map<String, AlfaToolEntry> _tools = {};

  ToolExecutor(this.ref);

  void register(AlfaToolEntry entry) {
    _tools[entry.definition.name] = entry;
  }

  void registerAll(List<AlfaToolEntry> entries) {
    for (final entry in entries) {
      _tools[entry.definition.name] = entry;
    }
  }

  List<AlfaToolDefinition> get definitions =>
      _tools.values.map((e) => e.definition).toList();

  Future<AlfaToolResult> execute(AlfaToolUse toolUse) async {
    final entry = _tools[toolUse.name];
    if (entry == null) {
      return AlfaToolResult(
        toolUseId: toolUse.id,
        content: 'Unknown tool: ${toolUse.name}',
        isError: true,
      );
    }

    try {
      final result = await entry.handler(ref, toolUse.input)
          .timeout(entry.timeout);
      return AlfaToolResult(
        toolUseId: toolUse.id,
        content: _encodeResult(result),
      );
    } on TimeoutException {
      return AlfaToolResult(
        toolUseId: toolUse.id,
        content: 'Tool ${toolUse.name} timed out after ${entry.timeout.inSeconds}s',
        isError: true,
      );
    } catch (e) {
      return AlfaToolResult(
        toolUseId: toolUse.id,
        content: 'Error: $e',
        isError: true,
      );
    }
  }

  Future<List<AlfaToolResult>> executeAll(List<AlfaToolUse> toolUses) {
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
