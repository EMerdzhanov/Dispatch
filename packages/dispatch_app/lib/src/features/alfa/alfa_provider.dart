import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_orchestrator.dart';
import 'alfa_types.dart';

class AlfaState {
  final AlfaStatus status;
  final List<AlfaChatEvent> messages;
  final bool configured;

  const AlfaState({
    this.status = AlfaStatus.idle,
    this.messages = const [],
    this.configured = false,
  });

  AlfaState copyWith({
    AlfaStatus? status,
    List<AlfaChatEvent>? messages,
    bool? configured,
  }) {
    return AlfaState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      configured: configured ?? this.configured,
    );
  }
}

class AlfaNotifier extends Notifier<AlfaState> {
  AlfaOrchestrator? _orchestrator;

  @override
  AlfaState build() {
    ref.onDispose(() => _orchestrator?.dispose());
    return const AlfaState();
  }

  Future<void> initialize() async {
    _orchestrator = AlfaOrchestrator(ref);
    await _orchestrator!.initialize();

    final configured = _orchestrator!.status != AlfaStatus.error;

    _orchestrator!.statusStream.listen((s) {
      state = state.copyWith(status: s);
    });

    _orchestrator!.messageStream.listen((event) {
      state = state.copyWith(
        messages: [...state.messages, event],
      );
    });

    state = state.copyWith(configured: configured);
  }

  Future<void> sendMessage(String text) async {
    if (_orchestrator == null) return;
    await _orchestrator!.sendMessage(text);
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  /// Inject a task-triggered message into the Alfa orchestrator.
  /// Used when a task with [ALFA] prefix is created.
  Future<void> injectTask(String title, String description) async {
    if (_orchestrator == null) return;
    final message = 'New task assigned: $title'
        '${description.isNotEmpty ? '. Details: $description' : ''}. '
        'Handle this now.';
    await _orchestrator!.sendMessage(message);
  }
}

final alfaProvider =
    NotifierProvider<AlfaNotifier, AlfaState>(AlfaNotifier.new);
