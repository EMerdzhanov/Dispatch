import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'grace_orchestrator.dart';
import 'grace_types.dart';

class GraceState {
  final GraceStatus status;
  final List<GraceChatEvent> messages;
  final bool configured;

  const GraceState({
    this.status = GraceStatus.idle,
    this.messages = const [],
    this.configured = false,
  });

  GraceState copyWith({
    GraceStatus? status,
    List<GraceChatEvent>? messages,
    bool? configured,
  }) {
    return GraceState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      configured: configured ?? this.configured,
    );
  }
}

class GraceNotifier extends Notifier<GraceState> {
  GraceOrchestrator? _orchestrator;
  StreamSubscription<GraceStatus>? _statusSub;
  StreamSubscription<GraceChatEvent>? _messageSub;

  @override
  GraceState build() {
    ref.onDispose(() {
      _statusSub?.cancel();
      _messageSub?.cancel();
      _orchestrator?.dispose();
    });
    return const GraceState();
  }

  Future<void> initialize() async {
    _orchestrator = GraceOrchestrator(ref);
    await _orchestrator!.initialize();

    final configured = _orchestrator!.status != GraceStatus.error;

    _statusSub = _orchestrator!.statusStream.listen((s) {
      state = state.copyWith(status: s);
    });

    _messageSub = _orchestrator!.messageStream.listen((event) {
      state = state.copyWith(
        messages: [...state.messages, event],
      );
    });

    state = state.copyWith(configured: configured);
  }

  Future<void> sendMessage(String text, {List<GraceAttachment>? attachments}) async {
    if (_orchestrator == null) return;
    await _orchestrator!.sendMessage(text, attachments: attachments);
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  /// Inject a task-triggered message into the Grace orchestrator.
  /// Used when a task with [GRACE] prefix is created.
  Future<void> injectTask(String title, String description) async {
    if (_orchestrator == null) return;
    final message = 'New task assigned: $title'
        '${description.isNotEmpty ? '. Details: $description' : ''}. '
        'Handle this now.';
    await _orchestrator!.sendMessage(message);
  }
}

final graceProvider =
    NotifierProvider<GraceNotifier, GraceState>(GraceNotifier.new);
