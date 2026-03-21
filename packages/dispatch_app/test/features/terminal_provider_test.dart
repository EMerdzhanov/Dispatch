import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_app/src/features/terminal/terminal_provider.dart';
import 'package:dispatch_app/src/features/projects/projects_provider.dart';
import 'package:dispatch_app/src/core/models/terminal_entry.dart';

void main() {
  group('TerminalsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });
    tearDown(() => container.dispose());

    test('starts with empty terminals', () {
      final state = container.read(terminalsProvider);
      expect(state.terminals, isEmpty);
      expect(state.activeTerminalId, isNull);
    });

    test('addTerminal adds to group and state', () {
      final groupId =
          container.read(projectsProvider.notifier).findOrCreateGroup('/code');
      container.read(terminalsProvider.notifier).addTerminal(
            groupId,
            TerminalEntry(
              id: 't1',
              command: 'sh',
              cwd: '/code',
              status: TerminalStatus.running,
            ),
          );
      final state = container.read(terminalsProvider);
      expect(state.terminals.containsKey('t1'), true);
      final group = container.read(projectsProvider).groups.first;
      expect(group.terminalIds.contains('t1'), true);
    });

    test('setActiveTerminal updates active', () {
      final groupId =
          container.read(projectsProvider.notifier).findOrCreateGroup('/code');
      container.read(terminalsProvider.notifier).addTerminal(
            groupId,
            TerminalEntry(
              id: 't1',
              command: 'sh',
              cwd: '/code',
              status: TerminalStatus.running,
            ),
          );
      container.read(terminalsProvider.notifier).setActiveTerminal('t1');
      expect(container.read(terminalsProvider).activeTerminalId, 't1');
    });

    test('removeTerminal cleans up', () {
      final groupId =
          container.read(projectsProvider.notifier).findOrCreateGroup('/code');
      container.read(terminalsProvider.notifier).addTerminal(
            groupId,
            TerminalEntry(
              id: 't1',
              command: 'sh',
              cwd: '/code',
              status: TerminalStatus.running,
            ),
          );
      container.read(terminalsProvider.notifier).removeTerminal('t1');
      expect(container.read(terminalsProvider).terminals, isEmpty);
    });

    test('updateStatus changes terminal status', () {
      final groupId =
          container.read(projectsProvider.notifier).findOrCreateGroup('/code');
      container.read(terminalsProvider.notifier).addTerminal(
            groupId,
            TerminalEntry(
              id: 't1',
              command: 'sh',
              cwd: '/code',
              status: TerminalStatus.running,
            ),
          );
      container
          .read(terminalsProvider.notifier)
          .updateStatus('t1', TerminalStatus.exited, exitCode: 0);
      expect(
          container.read(terminalsProvider).terminals['t1']!.status,
          TerminalStatus.exited);
    });

    test('toggleZenMode toggles', () {
      container.read(terminalsProvider.notifier).toggleZenMode();
      expect(container.read(terminalsProvider).zenMode, true);
      container.read(terminalsProvider.notifier).toggleZenMode();
      expect(container.read(terminalsProvider).zenMode, false);
    });
  });
}
