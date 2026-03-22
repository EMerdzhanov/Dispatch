import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_app/src/core/theme/app_theme.dart';
import 'package:dispatch_app/src/core/theme/color_theme.dart';
import 'package:dispatch_app/src/features/projects/tab_bar.dart';
import 'package:dispatch_app/src/features/projects/welcome_screen.dart';
import 'package:dispatch_app/src/features/projects/projects_provider.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  final theme = AppTheme(ColorTheme.fromId('dispatch-dark'));
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: theme.dark, home: Scaffold(body: child)),
  );
}

void main() {
  group('ProjectTabBar', () {
    testWidgets('renders a tab for each project group', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProjectTabBar(
            onOpenFolder: () {},
            onNewTab: () {},
            onOpenSettings: () {},
            onOpenShortcuts: () {},
          ),
        ),
      );

      // Read the container and add two groups
      final element = tester.element(find.byType(ProjectTabBar));
      final container = ProviderScope.containerOf(element);
      container.read(projectsProvider.notifier).findOrCreateGroup('/code/alpha');
      container.read(projectsProvider.notifier).findOrCreateGroup('/code/beta');

      await tester.pump();

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
    });

    testWidgets('tapping a tab sets it as the active group', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProjectTabBar(
            onOpenFolder: () {},
            onNewTab: () {},
            onOpenSettings: () {},
            onOpenShortcuts: () {},
          ),
        ),
      );

      final element = tester.element(find.byType(ProjectTabBar));
      final container = ProviderScope.containerOf(element);
      container.read(projectsProvider.notifier).findOrCreateGroup('/code/alpha');
      final betaId = container.read(projectsProvider.notifier).findOrCreateGroup('/code/beta');

      await tester.pump();

      // Tap the 'beta' tab
      await tester.tap(find.text('beta'));
      await tester.pump();

      expect(container.read(projectsProvider).activeGroupId, betaId);
    });

    testWidgets('"+" button is present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProjectTabBar(
            onOpenFolder: () {},
            onNewTab: () {},
            onOpenSettings: () {},
            onOpenShortcuts: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('open_folder_button')), findsOneWidget);
    });

    testWidgets('"+" button triggers onOpenFolder callback', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          ProjectTabBar(
            onOpenFolder: () => called = true,
            onNewTab: () {},
            onOpenSettings: () {},
            onOpenShortcuts: () {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_folder_button')));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('settings and shortcuts buttons are present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProjectTabBar(
            onOpenFolder: () {},
            onNewTab: () {},
            onOpenSettings: () {},
            onOpenShortcuts: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('open_settings_button')), findsOneWidget);
      expect(find.byKey(const Key('open_shortcuts_button')), findsOneWidget);
    });
  });

  group('WelcomeScreen', () {
    testWidgets('renders Open Folder button', (tester) async {
      await tester.pumpWidget(
        _wrap(WelcomeScreen(onOpenFolder: () {})),
      );

      expect(find.byKey(const Key('open_folder_button')), findsOneWidget);
      expect(find.text('Open Folder'), findsOneWidget);
    });

    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(WelcomeScreen(onOpenFolder: () {})),
      );

      expect(find.text('Welcome to Dispatch'), findsOneWidget);
      expect(find.text('Open a project folder to get started'), findsOneWidget);
    });

    testWidgets('Open Folder button triggers callback', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(WelcomeScreen(onOpenFolder: () => called = true)),
      );

      await tester.tap(find.byKey(const Key('open_folder_button')));
      await tester.pump();

      expect(called, isTrue);
    });
  });
}
