import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_app/src/features/settings/settings_provider.dart';

void main() {
  group('SettingsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });
    tearDown(() => container.dispose());

    test('starts with default values', () {
      final settings = container.read(settingsProvider);
      expect(settings.shell, '/bin/zsh');
      expect(settings.fontFamily, 'JetBrains Mono');
      expect(settings.fontSize, 13);
      expect(settings.lineHeight, 1.2);
      expect(settings.scanInterval, 10000);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.soundEnabled, isTrue);
      expect(settings.screenshotFolder, '');
    });

    test('update changes specific fields', () {
      container.read(settingsProvider.notifier).update(
        shell: '/bin/bash',
        fontSize: 16,
      );
      final settings = container.read(settingsProvider);
      expect(settings.shell, '/bin/bash');
      expect(settings.fontSize, 16);
    });

    test('update preserves unspecified fields', () {
      container.read(settingsProvider.notifier).update(shell: '/bin/bash');
      final settings = container.read(settingsProvider);
      // Changed
      expect(settings.shell, '/bin/bash');
      // Unchanged
      expect(settings.fontFamily, 'JetBrains Mono');
      expect(settings.fontSize, 13);
      expect(settings.lineHeight, 1.2);
      expect(settings.scanInterval, 10000);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.soundEnabled, isTrue);
      expect(settings.screenshotFolder, '');
    });
  });
}
