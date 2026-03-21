import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppShortcuts {
  static const newTerminal = SingleActivator(LogicalKeyboardKey.keyN, meta: true);
  static const newTab = SingleActivator(LogicalKeyboardKey.keyT, meta: true);
  static const closePane = SingleActivator(LogicalKeyboardKey.keyW, meta: true);
  static const openSearch = SingleActivator(LogicalKeyboardKey.keyK, meta: true);
  static const openPalette = SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true);
  static const splitHorizontal = SingleActivator(LogicalKeyboardKey.keyD, meta: true);
  static const splitVertical = SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true);
  static const zenMode = SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true);
  static const openSettings = SingleActivator(LogicalKeyboardKey.comma, meta: true);
  static const saveTemplate = SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true);

  static Map<ShortcutActivator, Intent> get bindings => {
    newTerminal: const NewTerminalIntent(),
    newTab: const NewTabIntent(),
    closePane: const ClosePaneIntent(),
    openSearch: const OpenSearchIntent(),
    openPalette: const OpenPaletteIntent(),
    splitHorizontal: const SplitHorizontalIntent(),
    splitVertical: const SplitVerticalIntent(),
    zenMode: const ToggleZenModeIntent(),
    openSettings: const OpenSettingsIntent(),
    saveTemplate: const SaveTemplateIntent(),
  };
}

class NewTerminalIntent extends Intent { const NewTerminalIntent(); }
class NewTabIntent extends Intent { const NewTabIntent(); }
class ClosePaneIntent extends Intent { const ClosePaneIntent(); }
class OpenSearchIntent extends Intent { const OpenSearchIntent(); }
class OpenPaletteIntent extends Intent { const OpenPaletteIntent(); }
class SplitHorizontalIntent extends Intent { const SplitHorizontalIntent(); }
class SplitVerticalIntent extends Intent { const SplitVerticalIntent(); }
class ToggleZenModeIntent extends Intent { const ToggleZenModeIntent(); }
class OpenSettingsIntent extends Intent { const OpenSettingsIntent(); }
class SaveTemplateIntent extends Intent { const SaveTemplateIntent(); }
