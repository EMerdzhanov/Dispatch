import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/color_theme.dart';

class AppSettings {
  final String shell;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final int scanInterval;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final String screenshotFolder;

  const AppSettings({
    this.shell = '/bin/zsh',
    this.fontFamily = 'JetBrains Mono',
    this.fontSize = 13,
    this.lineHeight = 1.2,
    this.scanInterval = 10000,
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.screenshotFolder = '',
  });

  AppSettings copyWith({
    String? shell,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    int? scanInterval,
    bool? notificationsEnabled,
    bool? soundEnabled,
    String? screenshotFolder,
  }) {
    return AppSettings(
      shell: shell ?? this.shell,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      scanInterval: scanInterval ?? this.scanInterval,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      screenshotFolder: screenshotFolder ?? this.screenshotFolder,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void update({
    String? shell,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    int? scanInterval,
    bool? notificationsEnabled,
    bool? soundEnabled,
    String? screenshotFolder,
  }) {
    state = state.copyWith(
      shell: shell,
      fontFamily: fontFamily,
      fontSize: fontSize,
      lineHeight: lineHeight,
      scanInterval: scanInterval,
      notificationsEnabled: notificationsEnabled,
      soundEnabled: soundEnabled,
      screenshotFolder: screenshotFolder,
    );
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class ThemeNotifier extends Notifier<String> {
  @override
  String build() => 'dispatch-dark';

  void setTheme(String id) {
    state = id;
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, String>(ThemeNotifier.new);

final activeThemeProvider = Provider<ColorTheme>((ref) {
  final id = ref.watch(themeProvider);
  return ColorTheme.fromId(id);
});
