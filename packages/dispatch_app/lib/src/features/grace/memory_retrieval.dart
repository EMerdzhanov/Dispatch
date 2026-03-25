import 'dart:convert';

import 'claude_client.dart';
import 'grace_types.dart';
import '../../core/database/database.dart';

/// Scores candidate memories for relevance using Claude.
/// Returns list of relevant memory IDs.
///
/// Falls back to all candidate IDs on any error (network, parse, timeout).
Future<List<int>> scoreMemoryRelevance(
  ClaudeClient client,
  String conversationContext,
  List<GraceMemory> candidates,
) async {
  if (candidates.isEmpty) return [];

  final memoriesJson = candidates.map((m) => {
    'id': m.id,
    'content': m.content,
    'category': m.category,
    'tags': m.tags,
  }).toList();

  final userMessage = jsonEncode({
    'context': conversationContext,
    'memories': memoriesJson,
  });

  try {
    final response = await client.sendMessage(
      systemPrompt:
          'You are a memory relevance scorer. Given a conversation context and a list '
          'of memories, return ONLY a JSON array of the IDs of memories that are relevant '
          'to this conversation. Example: [1, 5, 12]. Return [] if none are relevant. '
          'No explanation, no markdown — just the JSON array.',
      messages: [
        GraceMessage(role: MessageRole.user, text: userMessage),
      ],
      tools: [],
      maxTokens: 256,
    ).timeout(const Duration(seconds: 10));

    final text = response.text.trim();
    final ids = (jsonDecode(text) as List<dynamic>).cast<int>();
    return ids;
  } catch (_) {
    // Fallback: return all candidate IDs (noisy but functional)
    return candidates.map((m) => m.id).toList();
  }
}
