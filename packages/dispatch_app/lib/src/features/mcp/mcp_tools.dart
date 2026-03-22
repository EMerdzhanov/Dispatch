import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mcp_protocol.dart';

/// Signature for an MCP tool handler function.
typedef McpToolHandler = Future<Map<String, dynamic>> Function(
  Ref ref,
  Map<String, dynamic> params,
);

/// Describes an MCP tool with its schema and handler.
class McpToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final McpToolHandler handler;

  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// Registry of all MCP tools. Populated at server startup.
class McpToolRegistry {
  final Map<String, McpToolDefinition> _tools = {};

  void register(McpToolDefinition tool) {
    _tools[tool.name] = tool;
  }

  void registerAll(List<McpToolDefinition> tools) {
    for (final tool in tools) {
      _tools[tool.name] = tool;
    }
  }

  McpToolDefinition? get(String name) => _tools[name];

  List<McpToolDefinition> get all => _tools.values.toList();

  List<Map<String, dynamic>> toJsonList() =>
      _tools.values.map((t) => t.toJson()).toList();

  Future<McpResponse> handle(Ref ref, McpRequest request) async {
    final tool = _tools[request.method];
    if (tool == null) {
      return McpResponse.methodNotFound(request.id, request.method);
    }
    try {
      final result = await tool.handler(ref, request.params);
      return McpResponse.success(request.id, result);
    } catch (e) {
      return McpResponse.internalError(request.id, e.toString());
    }
  }
}
