import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/preset.dart';

class PresetsState {
  final List<Preset> presets;
  const PresetsState({this.presets = const []});
}

class PresetsNotifier extends Notifier<PresetsState> {
  @override
  PresetsState build() => PresetsState(presets: Preset.defaults);

  void setPresets(List<Preset> presets) {
    state = PresetsState(presets: presets);
  }

  void addPreset(Preset preset) {
    state = PresetsState(presets: [...state.presets, preset]);
  }

  void removePreset(int index) {
    final updated = [...state.presets]..removeAt(index);
    state = PresetsState(presets: updated);
  }
}

final presetsProvider =
    NotifierProvider<PresetsNotifier, PresetsState>(PresetsNotifier.new);
