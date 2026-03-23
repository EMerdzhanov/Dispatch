import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'mcp_protocol.dart';
import 'mcp_tools.dart';
import 'tools/observe_tools.dart';
import 'tools/act_tools.dart';
import 'tools/orchestrate_tools.dart';
import 'tools/filesystem_tools.dart';

class McpServer {
  final Ref ref;
  final McpToolRegistry _registry = McpToolRegistry();
  final List<StreamController<String>> _sseClients = [];

  HttpServer? _server;
  int _port = 3900;
  String? _authToken;
  bool _bindAll = false;
  int _requestCount = 0;
  final List<McpActivityEntry> activityLog = [];

  int get port => _port;
  int get connectionCount => _sseClients.length;
  bool get isRunning => _server != null;

  McpServer(this.ref) {
    _registry.registerAll(observeTools());
    _registry.registerAll(actTools());
    _registry.registerAll(orchestrateTools());
    _registry.registerAll(filesystemTools());
  }

  Future<int> start({
    int port = 3900,
    String? authToken,
    bool bindAll = false,
  }) async {
    _authToken = authToken;
    _bindAll = bindAll;

    final router = Router()
      ..post('/mcp', _handleRpc)
      ..get('/mcp/sse', _handleSse)
      ..get('/mcp/health', _handleHealth);

    final handler = const shelf.Pipeline()
        .addMiddleware(_authMiddleware())
        .addHandler(router.call);

    // Try the requested port, fall back to random
    final address = bindAll ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4;
    try {
      _server = await shelf_io.serve(handler, address, port);
      _port = port;
    } catch (_) {
      // Port in use — try a random port
      _server = await shelf_io.serve(handler, address, 0);
      _port = _server!.port;
    }

    return _port;
  }

  Future<void> stop() async {
    for (final client in _sseClients) {
      await client.close();
    }
    _sseClients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  /// Push a notification to all connected SSE clients.
  void notify(McpNotification notification) {
    final event = notification.toSseEvent();
    for (final client in _sseClients) {
      client.add(event);
    }
  }

  shelf.Middleware _authMiddleware() {
    return (shelf.Handler handler) {
      return (shelf.Request request) {
        if (_authToken == null || _authToken!.isEmpty) {
          return handler(request);
        }
        final auth = request.headers['authorization'];
        if (auth != 'Bearer $_authToken') {
          return shelf.Response.forbidden(
            jsonEncode({'error': 'Invalid or missing authorization token'}),
            headers: {'content-type': 'application/json'},
          );
        }
        return handler(request);
      };
    };
  }

  /// Format a JSON-RPC response as either JSON or SSE based on Accept header.
  shelf.Response _respond(shelf.Request request, McpResponse response) {
    final accept = request.headers['accept'] ?? '';
    final jsonStr = response.toJsonString();

    if (accept.contains('text/event-stream')) {
      // SSE format: event + data lines
      final sseBody = 'event: message\ndata: $jsonStr\n\n';
      return shelf.Response.ok(sseBody, headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
        'connection': 'keep-alive',
      });
    }

    return shelf.Response.ok(jsonStr,
        headers: {'content-type': 'application/json'});
  }

  Future<shelf.Response> _handleRpc(shelf.Request request) async {
    final body = await request.readAsString();
    Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return shelf.Response(400,
          body: jsonEncode({'error': 'Invalid JSON'}),
          headers: {'content-type': 'application/json'});
    }

    final mcpRequest = McpRequest.fromJson(json);

    // Handle JSON-RPC notifications (no id) — return 202 Accepted
    if (mcpRequest.id == null) {
      return shelf.Response(202);
    }

    // Handle MCP protocol methods
    if (mcpRequest.method == 'initialize') {
      return _respond(request, McpResponse.success(mcpRequest.id, {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'tools': {'listChanged': false},
        },
        'serverInfo': {
          'name': 'dispatch',
          'version': '0.1.0',
        },
      }));
    }

    if (mcpRequest.method == 'tools/list') {
      return _respond(request, McpResponse.success(mcpRequest.id, {
        'tools': _registry.toJsonList(),
      }));
    }

    if (mcpRequest.method == 'tools/call') {
      final toolName = mcpRequest.params['name'] as String?;
      final toolParams =
          (mcpRequest.params['arguments'] as Map<String, dynamic>?) ?? {};
      if (toolName == null) {
        return _respond(request,
          McpResponse.invalidParams(mcpRequest.id, 'Missing tool name'));
      }

      final toolRequest =
          McpRequest(method: toolName, params: toolParams, id: mcpRequest.id);
      final response = await _registry.handle(ref, toolRequest);

      // Log activity
      _requestCount++;
      activityLog.insert(0, McpActivityEntry(
        timestamp: DateTime.now(),
        toolName: toolName,
        agentId: request.headers['x-agent-id'] ?? 'unknown',
      ));
      if (activityLog.length > 100) activityLog.removeLast();

      // Wrap tool result in MCP content format
      McpResponse mcpResponse;
      if (response.error != null) {
        mcpResponse = McpResponse.success(mcpRequest.id, {
          'content': [
            {'type': 'text', 'text': response.error!.message},
          ],
          'isError': true,
        });
      } else {
        mcpResponse = McpResponse.success(mcpRequest.id, {
          'content': [
            {'type': 'text', 'text': jsonEncode(response.result)},
          ],
        });
      }

      return _respond(request, mcpResponse);
    }

    // Unknown method
    return _respond(request,
      McpResponse.methodNotFound(mcpRequest.id, mcpRequest.method));
  }

  Future<shelf.Response> _handleSse(shelf.Request request) async {
    final controller = StreamController<String>();
    _sseClients.add(controller);

    // Remove client on disconnect
    controller.onCancel = () {
      _sseClients.remove(controller);
    };

    return shelf.Response.ok(
      controller.stream,
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
        'connection': 'keep-alive',
      },
    );
  }

  Future<shelf.Response> _handleHealth(shelf.Request request) async {
    return shelf.Response.ok(
      jsonEncode({
        'status': 'ok',
        'version': '0.1.0',
        'connections': _sseClients.length,
        'requestsServed': _requestCount,
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  static String generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

class McpActivityEntry {
  final DateTime timestamp;
  final String toolName;
  final String agentId;

  McpActivityEntry({
    required this.timestamp,
    required this.toolName,
    required this.agentId,
  });
}
