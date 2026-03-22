import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Standalone stdio-to-HTTP bridge for MCP.
///
/// This process reads JSON-RPC 2.0 messages from stdin, forwards them to
/// the running Dispatch app's HTTP server via loopback, and writes responses
/// to stdout.
///
/// Usage: dart run bin/dispatch_mcp_stdio.dart [--port PORT] [--token TOKEN]
void main(List<String> args) async {
  var port = 3900;
  String? token;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--port' && i + 1 < args.length) {
      port = int.parse(args[++i]);
    } else if (args[i] == '--token' && i + 1 < args.length) {
      token = args[++i];
    }
  }

  final baseUrl = 'http://localhost:$port/mcp';
  final client = HttpClient();

  // Read lines from stdin and forward to HTTP
  final lines = stdin
      .transform(const Utf8Decoder())
      .transform(const LineSplitter());

  await for (final line in lines) {
    if (line.trim().isEmpty) continue;

    try {
      final request = client.postUrl(Uri.parse(baseUrl));
      final httpRequest = await request;
      httpRequest.headers.set('content-type', 'application/json');
      if (token != null) {
        httpRequest.headers.set('authorization', 'Bearer $token');
      }
      httpRequest.write(line);
      final response = await httpRequest.close();
      final responseBody = await response.transform(const Utf8Decoder()).join();
      stdout.writeln(responseBody);
    } catch (e) {
      final errorResponse = jsonEncode({
        'jsonrpc': '2.0',
        'error': {'code': -32000, 'message': 'Bridge error: $e'},
        'id': null,
      });
      stdout.writeln(errorResponse);
    }
  }

  client.close();
}
