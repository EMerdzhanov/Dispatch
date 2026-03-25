// Types for Claude API messages and tool use.

import 'dart:convert';

enum MessageRole { user, assistant }

class GraceAttachment {
  final String fileName;
  final String mimeType;
  final String base64Data;

  const GraceAttachment({
    required this.fileName,
    required this.mimeType,
    required this.base64Data,
  });

  bool get isImage => mimeType.startsWith('image/');

  Map<String, dynamic> toApiBlock() {
    if (isImage) {
      return {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mimeType,
          'data': base64Data,
        },
      };
    }
    // Non-image files: send as text with filename context
    return {
      'type': 'text',
      'text': '[$fileName]\n${utf8.decode(base64.decode(base64Data))}',
    };
  }
}

class GraceMessage {
  final MessageRole role;
  final String? text;
  final List<GraceToolUse>? toolUses;
  final List<GraceToolResult>? toolResults;
  final List<GraceAttachment>? attachments;

  const GraceMessage({
    required this.role,
    this.text,
    this.toolUses,
    this.toolResults,
    this.attachments,
  });

  Map<String, dynamic> toApi() {
    if (toolResults != null && toolResults!.isNotEmpty) {
      return {
        'role': 'user',
        'content': toolResults!.map((r) => r.toApi()).toList(),
      };
    }
    if (toolUses != null && toolUses!.isNotEmpty) {
      final content = <Map<String, dynamic>>[];
      if (text != null) {
        content.add({'type': 'text', 'text': text});
      }
      content.addAll(toolUses!.map((t) => t.toApi()));
      return {'role': 'assistant', 'content': content};
    }
    // If attachments present, use content blocks
    if (attachments != null && attachments!.isNotEmpty) {
      final content = <Map<String, dynamic>>[];
      for (final a in attachments!) {
        content.add(a.toApiBlock());
      }
      if (text != null && text!.isNotEmpty) {
        content.add({'type': 'text', 'text': text});
      }
      return {'role': role.name, 'content': content};
    }
    return {'role': role.name, 'content': text ?? ''};
  }
}

class GraceToolUse {
  final String id;
  final String name;
  final Map<String, dynamic> input;

  const GraceToolUse({
    required this.id,
    required this.name,
    required this.input,
  });

  Map<String, dynamic> toApi() => {
        'type': 'tool_use',
        'id': id,
        'name': name,
        'input': input,
      };

  factory GraceToolUse.fromApi(Map<String, dynamic> json) => GraceToolUse(
        id: json['id'] as String,
        name: json['name'] as String,
        input: (json['input'] as Map<String, dynamic>?) ?? {},
      );
}

class GraceToolResult {
  final String toolUseId;
  final String content;
  final bool isError;

  const GraceToolResult({
    required this.toolUseId,
    required this.content,
    this.isError = false,
  });

  Map<String, dynamic> toApi() => {
        'type': 'tool_result',
        'tool_use_id': toolUseId,
        'content': content,
        if (isError) 'is_error': true,
      };
}

class GraceToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const GraceToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  Map<String, dynamic> toApi() => {
        'name': name,
        'description': description,
        'input_schema': inputSchema,
      };
}

enum GraceStatus { idle, thinking, executing, error }

// ---------------------------------------------------------------------------
// Chat events — defined here (not in grace_orchestrator.dart) so that tools
// can import and emit them without creating circular dependencies.
// ---------------------------------------------------------------------------

sealed class GraceChatEvent {
  const GraceChatEvent();

  factory GraceChatEvent.human(String text) = HumanMessageEvent;
  factory GraceChatEvent.grace(String text) = GraceMessageEvent;
  factory GraceChatEvent.graceDone(String text) = GraceDoneEvent;
  factory GraceChatEvent.delta(String text) = GraceDeltaEvent;
  factory GraceChatEvent.toolCall(
    String name,
    Map<String, dynamic> input,
    String result,
    bool isError,
  ) = ToolCallEvent;
}

class HumanMessageEvent extends GraceChatEvent {
  final String text;
  const HumanMessageEvent(this.text);
}

class GraceMessageEvent extends GraceChatEvent {
  final String text;
  const GraceMessageEvent(this.text);
}

class GraceDoneEvent extends GraceChatEvent {
  final String text;
  const GraceDoneEvent(this.text);
}

class GraceDeltaEvent extends GraceChatEvent {
  final String text;
  const GraceDeltaEvent(this.text);
}

class ToolCallEvent extends GraceChatEvent {
  final String name;
  final Map<String, dynamic> input;
  final String result;
  final bool isError;
  const ToolCallEvent(this.name, this.input, this.result, this.isError);
}
