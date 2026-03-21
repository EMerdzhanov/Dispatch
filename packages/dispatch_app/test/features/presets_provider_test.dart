import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_app/src/core/models/preset.dart';
import 'package:dispatch_app/src/features/presets/presets_provider.dart';

void main() {
  group('PresetsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });
    tearDown(() => container.dispose());

    test('starts with 4 defaults', () {
      final state = container.read(presetsProvider);
      expect(state.presets.length, 4);
      expect(state.presets, Preset.defaults);
    });

    test('addPreset adds to list', () {
      const newPreset = Preset(
        name: 'Custom',
        command: 'my-cmd',
        color: '#123456',
        icon: 'star',
      );
      container.read(presetsProvider.notifier).addPreset(newPreset);
      final state = container.read(presetsProvider);
      expect(state.presets.length, 5);
      expect(state.presets.last, newPreset);
    });

    test('removePreset removes by index', () {
      final initialName = container.read(presetsProvider).presets[0].name;
      container.read(presetsProvider.notifier).removePreset(0);
      final state = container.read(presetsProvider);
      expect(state.presets.length, 3);
      expect(state.presets.any((p) => p.name == initialName), isFalse);
    });

    test('setPresets replaces entire list', () {
      const replacement = [
        Preset(name: 'Only One', command: 'one', color: '#ffffff', icon: 'box'),
      ];
      container.read(presetsProvider.notifier).setPresets(replacement);
      final state = container.read(presetsProvider);
      expect(state.presets.length, 1);
      expect(state.presets[0].name, 'Only One');
    });
  });
}
