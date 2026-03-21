import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_app/src/features/projects/projects_provider.dart';

void main() {
  group('ProjectsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });
    tearDown(() => container.dispose());

    test('starts with empty groups', () {
      final state = container.read(projectsProvider);
      expect(state.groups, isEmpty);
      expect(state.activeGroupId, isNull);
    });

    test('findOrCreateGroup creates new group', () {
      container.read(projectsProvider.notifier).findOrCreateGroup('/code/foo');
      final state = container.read(projectsProvider);
      expect(state.groups.length, 1);
      expect(state.groups[0].label, 'foo');
      expect(state.groups[0].cwd, '/code/foo');
    });

    test('findOrCreateGroup returns existing', () {
      final id1 =
          container.read(projectsProvider.notifier).findOrCreateGroup('/code/foo');
      final id2 =
          container.read(projectsProvider.notifier).findOrCreateGroup('/code/foo');
      expect(id1, id2);
      expect(container.read(projectsProvider).groups.length, 1);
    });

    test('removeGroup cleans up', () {
      final id =
          container.read(projectsProvider.notifier).findOrCreateGroup('/code/foo');
      container.read(projectsProvider.notifier).removeGroup(id);
      expect(container.read(projectsProvider).groups, isEmpty);
    });

    test('setActiveGroup changes active', () {
      final id =
          container.read(projectsProvider.notifier).findOrCreateGroup('/code/foo');
      container.read(projectsProvider.notifier).setActiveGroup(id);
      expect(container.read(projectsProvider).activeGroupId, id);
    });

    test('reorderGroups swaps positions', () {
      container.read(projectsProvider.notifier).findOrCreateGroup('/code/a');
      container.read(projectsProvider.notifier).findOrCreateGroup('/code/b');
      container.read(projectsProvider.notifier).reorderGroups(0, 1);
      expect(container.read(projectsProvider).groups[0].label, 'b');
      expect(container.read(projectsProvider).groups[1].label, 'a');
    });
  });
}
