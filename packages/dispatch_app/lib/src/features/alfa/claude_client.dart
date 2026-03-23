import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'alfa_types.dart';

/// HTTP client for Claude Messages API with streaming support.
class ClaudeClient {
  final String apiKey;
  final String model;
  final HttpClient _http = HttpClient();

  static const _baseUrl = 'api.anthropic.com';
  static const _apiVersion = '2023-06-01';

  ClaudeClient({required this.apiKey, this.model = 'claude-sonnet-4-6'});

  /// Send a messages request and stream the response.
  ///
  /// Yields text deltas as strings. When tool_use blocks are encountered,
  /// they are collected and returned via [onToolUse] after the stream ends.
  /// Returns the stop reason.
  Future<ClaudeResponse> sendMessage({
    required String systemPrompt,
    required List<AlfaMessage> messages,
    required List<AlfaToolDefinition> tools,
    int maxTokens = 8096,
    void Function(String delta)? onTextDelta,
  }) async {
    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'system': systemPrompt,
      'messages': messages.map((m) => m.toApi()).toList(),
      if (tools.isNotEmpty)
        'tools': tools.map((t) => t.toApi()).toList(),
      'stream': true,
    });

    final request = await _http.postUrl(
      Uri.https(_baseUrl, '/v1/messages'),
    );
    request.headers.set('content-type', 'application/json');
    request.headers.set('x-api-key', apiKey);
    request.headers.set('anthropic-version', _apiVersion);
    request.write(body);

    final response = await request.close();

    if (response.statusCode != 200) {
      final errorBody = await response.transform(utf8.decoder).join();
      throw ClaudeApiError(response.statusCode, errorBody);
    }

    // Parse SSE stream
    final textBuffer = StringBuffer();
    final toolUses = <AlfaToolUse>[];
    String stopReason = 'end_turn';

    // Track tool_use blocks being built
    String? currentToolId;
    String? currentToolName;
    final currentToolInput = StringBuffer();

    await for (final chunk in response.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]' || data.isEmpty) continue;

        Map<String, dynamic> event;
        try {
          event = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        final type = event['type'] as String?;

        if (type == 'content_block_start') {
          final block = event['content_block'] as Map<String, dynamic>?;
          if (block != null && block['type'] == 'tool_use') {
            currentToolId = block['id'] as String;
            currentToolName = block['name'] as String;
            currentToolInput.clear();
          }
        } else if (type == 'content_block_delta') {
          final delta = event['delta'] as Map<String, dynamic>?;
          if (delta != null) {
            if (delta['type'] == 'text_delta') {
              final text = delta['text'] as String? ?? '';
              textBuffer.write(text);
              onTextDelta?.call(text);
            } else if (delta['type'] == 'input_json_delta') {
              currentToolInput.write(delta['partial_json'] ?? '');
            }
          }
        } else if (type == 'content_block_stop') {
          if (currentToolId != null && currentToolName != null) {
            Map<String, dynamic> input = {};
            final inputStr = currentToolInput.toString();
            if (inputStr.isNotEmpty) {
              try {
                input = jsonDecode(inputStr) as Map<String, dynamic>;
              } catch (_) {}
            }
            toolUses.add(AlfaToolUse(
              id: currentToolId,
              name: currentToolName,
              input: input,
            ));
            currentToolId = null;
            currentToolName = null;
            currentToolInput.clear();
          }
        } else if (type == 'message_delta') {
          final delta = event['delta'] as Map<String, dynamic>?;
          stopReason = delta?['stop_reason'] as String? ?? stopReason;
        }
      }
    }

    return ClaudeResponse(
      text: textBuffer.toString(),
      toolUses: toolUses,
      stopReason: stopReason,
    );
  }

  void close() => _http.close();
}

class ClaudeResponse {
  final String text;
  final List<AlfaToolUse> toolUses;
  final String stopReason;

  const ClaudeResponse({
    required this.text,
    required this.toolUses,
    required this.stopReason,
  });

  bool get hasToolUse => toolUses.isNotEmpty;
}

class ClaudeApiError implements Exception {
  final int statusCode;
  final String body;
  ClaudeApiError(this.statusCode, this.body);

  @override
  String toString() => 'ClaudeApiError($statusCode): $body';
}
