import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dispatch_app/src/core/theme/app_theme.dart';
import 'package:dispatch_app/src/features/command_palette/command_palette.dart';
import 'package:dispatch_app/src/features/command_palette/quick_switcher.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('fuzzy matching', () {
    test('"cla" matches "Claude Code"', () {
      expect(fuzzyScore('cla', 'Claude Code'), greaterThan(0));
    });

    test('"sh" matches "Shell"', () {
      expect(fuzzyScore('sh', 'Shell'), greaterThan(0));
    });

    test('"xyz" does not match "Claude Code"', () {
      expect(fuzzyScore('xyz', 'Claude Code'), equals(0));
    });

    test('empty query matches anything', () {
      expect(fuzzyScore('', 'Claude Code'), greaterThan(0));
    });

    test('exact substring scores higher than fuzzy match', () {
      final exact = fuzzyScore('claude', 'claude');
      final fuzzy = fuzzyScore('cld', 'claude');
      expect(exact, greaterThan(fuzzy));
    });

    test('"sh" matches "bash"', () {
      expect(fuzzyScore('sh', 'bash'), greaterThan(0));
    });

    test('"abc" does not match "xyz"', () {
      expect(fuzzyScore('abc', 'xyz'), equals(0));
    });
  });

  group('CommandPalette', () {
    testWidgets('shows input when open', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommandPalette(
            open: true,
            onClose: () {},
            onSpawn: (command, {env}) {},
          ),
        ),
      );

      expect(find.byKey(const Key('command_palette_input')), findsOneWidget);
    });

    testWidgets('is hidden when not open', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommandPalette(
            open: false,
            onClose: () {},
            onSpawn: (command, {env}) {},
          ),
        ),
      );

      expect(find.byKey(const Key('command_palette_input')), findsNothing);
    });

    testWidgets('shows default presets when query is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommandPalette(
            open: true,
            onClose: () {},
            onSpawn: (command, {env}) {},
          ),
        ),
      );
      await tester.pump();

      // Default presets include 'Claude Code', 'Shell', etc.
      expect(find.text('Claude Code'), findsOneWidget);
      expect(find.text('Shell'), findsOneWidget);
    });

    testWidgets('filters results based on query', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommandPalette(
            open: true,
            onClose: () {},
            onSpawn: (command, {env}) {},
          ),
        ),
      );
      await tester.pump();

      // Type 'shell' to filter
      await tester.enterText(
        find.byKey(const Key('command_palette_input')),
        'shell',
      );
      await tester.pump();

      expect(find.text('Shell'), findsOneWidget);
      // 'Claude Code' should not be visible for 'shell' query
      expect(find.text('Claude Code'), findsNothing);
    });

    testWidgets('calls onClose when backdrop is tapped', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 800,
            height: 600,
            child: CommandPalette(
              open: true,
              onClose: () => closed = true,
              onSpawn: (command, {env}) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap the backdrop (top-left corner, away from the centered panel)
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('calls onSpawn and onClose when result is tapped',
        (tester) async {
      String? spawnedCommand;
      var closed = false;

      await tester.pumpWidget(
        _wrap(
          CommandPalette(
            open: true,
            onClose: () => closed = true,
            onSpawn: (command, {env}) => spawnedCommand = command,
          ),
        ),
      );
      await tester.pump();

      // Tap 'Shell' preset
      await tester.tap(find.text('Shell'));
      await tester.pump();

      expect(spawnedCommand, isNotNull);
      expect(closed, isTrue);
    });
  });

  group('QuickSwitcher', () {
    testWidgets('shows input when open', (tester) async {
      await tester.pumpWidget(
        _wrap(
          QuickSwitcher(
            open: true,
            onClose: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('quick_switcher_input')), findsOneWidget);
    });

    testWidgets('is hidden when not open', (tester) async {
      await tester.pumpWidget(
        _wrap(
          QuickSwitcher(
            open: false,
            onClose: () {},
          ),
        ),
      );

      expect(find.byKey(const Key('quick_switcher_input')), findsNothing);
    });

    testWidgets('shows placeholder text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          QuickSwitcher(
            open: true,
            onClose: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Switch to terminal...'), findsOneWidget);
    });

    testWidgets('calls onClose when backdrop is tapped', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 800,
            height: 600,
            child: QuickSwitcher(
              open: true,
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tapAt(const Offset(10, 10));
      await tester.pump();

      expect(closed, isTrue);
    });
  });
}
