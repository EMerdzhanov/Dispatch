// Types for Claude API messages and tool use.

enum MessageRole { user, assistant }

class AlfaMessage {
  final MessageRole role;
  final String? text;
  final List<AlfaToolUse>? toolUses;
  final List<AlfaToolResult>? toolResults;

  const AlfaMessage({
    required this.role,
    this.text,
    this.toolUses,
    this.toolResults,
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
    return {'role': role.name, 'content': text ?? ''};
  }
}

class AlfaToolUse {
  final String id;
  final String name;
  final Map<String, dynamic> input;

  const AlfaToolUse({
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

  factory AlfaToolUse.fromApi(Map<String, dynamic> json) => AlfaToolUse(
        id: json['id'] as String,
        name: json['name'] as String,
        input: (json['input'] as Map<String, dynamic>?) ?? {},
      );
}

class AlfaToolResult {
  final String toolUseId;
  final String content;
  final bool isError;

  const AlfaToolResult({
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

class AlfaToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const AlfaToolDefinition({
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

enum AlfaStatus { idle, thinking, executing, error }

// ---------------------------------------------------------------------------
// Chat events — defined here (not in alfa_orchestrator.dart) so that tools
// can import and emit them without creating circular dependencies.
// ---------------------------------------------------------------------------

sealed class AlfaChatEvent {
  const AlfaChatEvent();

  factory AlfaChatEvent.human(String text) = HumanMessageEvent;
  factory AlfaChatEvent.alfa(String text) = AlfaMessageEvent;
  factory AlfaChatEvent.alfaDone(String text) = AlfaDoneEvent;
  factory AlfaChatEvent.delta(String text) = AlfaDeltaEvent;
  factory AlfaChatEvent.toolCall(
    String name,
    Map<String, dynamic> input,
    String result,
    bool isError,
  ) = ToolCallEvent;
}

class HumanMessageEvent extends AlfaChatEvent {
  final String text;
  const HumanMessageEvent(this.text);
}

class AlfaMessageEvent extends AlfaChatEvent {
  final String text;
  const AlfaMessageEvent(this.text);
}

class AlfaDoneEvent extends AlfaChatEvent {
  final String text;
  const AlfaDoneEvent(this.text);
}

class AlfaDeltaEvent extends AlfaChatEvent {
  final String text;
  const AlfaDeltaEvent(this.text);
}

class ToolCallEvent extends AlfaChatEvent {
  final String name;
  final Map<String, dynamic> input;
  final String result;
  final bool isError;
  const ToolCallEvent(this.name, this.input, this.result, this.isError);
}
