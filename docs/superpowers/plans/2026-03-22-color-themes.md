# Color Themes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 6 selectable color themes (Dispatch Dark, Monokai, Dracula, Nord, Solarized Dark, GitHub Dark) that style both the terminal and UI chrome, selected via a settings dropdown with immediate apply and SQLite persistence.

**Architecture:** A `ColorTheme` data class holds all 37 color fields (23 terminal + 12 UI chrome + 2 identity). Six built-in themes are `static const` instances. A Riverpod `NotifierProvider` holds the active theme id, persisted to SQLite. `AppTheme` is refactored from static constants to an instance that reads from the active `ColorTheme`. All 25 widget files are updated to use the theme instance.

**Tech Stack:** Flutter, Riverpod (NotifierProvider), Drift/SQLite, xterm_local (TerminalTheme)

**Spec:** `docs/superpowers/specs/2026-03-22-color-themes-design.md`

---

### Task 1: Create ColorTheme data class

**Files:**
- Create: `packages/dispatch_app/lib/src/core/theme/color_theme.dart`

- [ ] **Step 1: Create the ColorTheme class with all fields**

Create `packages/dispatch_app/lib/src/core/theme/color_theme.dart` with a `const` constructor and 37 fields:

```dart
import 'package:flutter/material.dart';

class ColorTheme {
  final String id;
  final String name;

  // Terminal colors
  final Color foreground;
  final Color background;
  final Color cursor;
  final Color selection;
  final Color black;
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color magenta;
  final Color cyan;
  final Color white;
  final Color brightBlack;
  final Color brightRed;
  final Color brightGreen;
  final Color brightYellow;
  final Color brightBlue;
  final Color brightMagenta;
  final Color brightCyan;
  final Color brightWhite;
  final Color searchHitBackground;
  final Color searchHitBackgroundCurrent;
  final Color searchHitForeground;

  // UI chrome colors
  final Color uiBackground;
  final Color uiSurface;
  final Color uiSurfaceLight;
  final Color uiBorder;
  final Color uiTextPrimary;
  final Color uiTextSecondary;
  final Color uiAccent;
  final Color uiAccentRed;
  final Color uiAccentGreen;
  final Color uiAccentYellow;
  final Color uiTabTrack;
  final Color uiTabTrackBorder;

  const ColorTheme({
    required this.id,
    required this.name,
    required this.foreground,
    required this.background,
    required this.cursor,
    required this.selection,
    required this.black,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.magenta,
    required this.cyan,
    required this.white,
    required this.brightBlack,
    required this.brightRed,
    required this.brightGreen,
    required this.brightYellow,
    required this.brightBlue,
    required this.brightMagenta,
    required this.brightCyan,
    required this.brightWhite,
    required this.searchHitBackground,
    required this.searchHitBackgroundCurrent,
    required this.searchHitForeground,
    required this.uiBackground,
    required this.uiSurface,
    required this.uiSurfaceLight,
    required this.uiBorder,
    required this.uiTextPrimary,
    required this.uiTextSecondary,
    required this.uiAccent,
    required this.uiAccentRed,
    required this.uiAccentGreen,
    required this.uiAccentYellow,
    required this.uiTabTrack,
    required this.uiTabTrackBorder,
  });

  /// Look up a theme by id. Returns Dispatch Dark if not found.
  static ColorTheme fromId(String id) {
    return builtIn.firstWhere((t) => t.id == id, orElse: () => dispatchDark);
  }

  static const builtIn = [dispatchDark, monokai, dracula, nord, solarizedDark, githubDark];

  // ... theme constants defined in next steps
}
```

- [ ] **Step 2: Add the Dispatch Dark theme constant**

Add to the `ColorTheme` class. Values must match current hardcoded colors exactly (from `app_theme.dart` and `terminal_pane.dart`):

```dart
static const dispatchDark = ColorTheme(
  id: 'dispatch-dark',
  name: 'Dispatch Dark',
  foreground: Color(0xFFCCCCCC),
  background: Color(0xFF0A0A1A),
  cursor: Color(0xFFCCCCCC),
  selection: Color(0x603A6FD6),
  black: Color(0xFF0A0A1A),
  red: Color(0xFFE94560),
  green: Color(0xFF4CAF50),
  yellow: Color(0xFFF5A623),
  blue: Color(0xFF53A8FF),
  magenta: Color(0xFFC678DD),
  cyan: Color(0xFF56B6C2),
  white: Color(0xFFCCCCCC),
  brightBlack: Color(0xFF555555),
  brightRed: Color(0xFFFF6B81),
  brightGreen: Color(0xFF69F0AE),
  brightYellow: Color(0xFFFFD740),
  brightBlue: Color(0xFF82B1FF),
  brightMagenta: Color(0xFFE1ACFF),
  brightCyan: Color(0xFF84FFFF),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFF444444),
  searchHitBackgroundCurrent: Color(0xFFFFFF00),
  searchHitForeground: Color(0xFF000000),
  uiBackground: Color(0xFF0A0A1A),
  uiSurface: Color(0xFF12122A),
  uiSurfaceLight: Color(0xFF1A1A3A),
  uiBorder: Color(0xFF2A2A4A),
  uiTextPrimary: Color(0xFFCCCCCC),
  uiTextSecondary: Color(0xFF888888),
  uiAccent: Color(0xFF3A6FD6),
  uiAccentRed: Color(0xFFE94560),
  uiAccentGreen: Color(0xFF00CD00),
  uiAccentYellow: Color(0xFFF5A623),
  uiTabTrack: Color(0xFF060612),
  uiTabTrackBorder: Color(0xFF1A1A2A),
);
```

- [ ] **Step 3: Add remaining 5 theme constants**

Add Monokai, Dracula, Nord, Solarized Dark, and GitHub Dark using values from the spec. All values are in `docs/superpowers/specs/2026-03-22-color-themes-design.md` under "Theme Palettes".

```dart
static const monokai = ColorTheme(
  id: 'monokai',
  name: 'Monokai',
  foreground: Color(0xFFF8F8F2),
  background: Color(0xFF272822),
  cursor: Color(0xFFF8F8F0),
  selection: Color(0x6049483E),
  black: Color(0xFF272822),
  red: Color(0xFFF92672),
  green: Color(0xFFA6E22E),
  yellow: Color(0xFFE6DB74),
  blue: Color(0xFF66D9EF),
  magenta: Color(0xFFAE81FF),
  cyan: Color(0xFFA1EFE4),
  white: Color(0xFFF8F8F2),
  brightBlack: Color(0xFF75715E),
  brightRed: Color(0xFFF44747),
  brightGreen: Color(0xFFB5F76C),
  brightYellow: Color(0xFFF3EDA5),
  brightBlue: Color(0xFF8DE8FC),
  brightMagenta: Color(0xFFC7A5FF),
  brightCyan: Color(0xFFB5F7EF),
  brightWhite: Color(0xFFF9F8F5),
  searchHitBackground: Color(0xFF444444),
  searchHitBackgroundCurrent: Color(0xFFE6DB74),
  searchHitForeground: Color(0xFF272822),
  uiBackground: Color(0xFF1E1F1C),
  uiSurface: Color(0xFF272822),
  uiSurfaceLight: Color(0xFF3E3D32),
  uiBorder: Color(0xFF49483E),
  uiTextPrimary: Color(0xFFF8F8F2),
  uiTextSecondary: Color(0xFF75715E),
  uiAccent: Color(0xFFF92672),
  uiAccentRed: Color(0xFFF92672),
  uiAccentGreen: Color(0xFFA6E22E),
  uiAccentYellow: Color(0xFFE6DB74),
  uiTabTrack: Color(0xFF1A1B18),
  uiTabTrackBorder: Color(0xFF272822),
);

static const dracula = ColorTheme(
  id: 'dracula',
  name: 'Dracula',
  foreground: Color(0xFFF8F8F2),
  background: Color(0xFF282A36),
  cursor: Color(0xFFF8F8F2),
  selection: Color(0x6044475A),
  black: Color(0xFF282A36),
  red: Color(0xFFFF5555),
  green: Color(0xFF50FA7B),
  yellow: Color(0xFFF1FA8C),
  blue: Color(0xFFBD93F9),
  magenta: Color(0xFFFF79C6),
  cyan: Color(0xFF8BE9FD),
  white: Color(0xFFF8F8F2),
  brightBlack: Color(0xFF6272A4),
  brightRed: Color(0xFFFF6E6E),
  brightGreen: Color(0xFF69FF94),
  brightYellow: Color(0xFFFFFFA5),
  brightBlue: Color(0xFFD6ACFF),
  brightMagenta: Color(0xFFFF92DF),
  brightCyan: Color(0xFFA4FFFF),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFF444444),
  searchHitBackgroundCurrent: Color(0xFFF1FA8C),
  searchHitForeground: Color(0xFF282A36),
  uiBackground: Color(0xFF21222C),
  uiSurface: Color(0xFF282A36),
  uiSurfaceLight: Color(0xFF343746),
  uiBorder: Color(0xFF44475A),
  uiTextPrimary: Color(0xFFF8F8F2),
  uiTextSecondary: Color(0xFF6272A4),
  uiAccent: Color(0xFFBD93F9),
  uiAccentRed: Color(0xFFFF5555),
  uiAccentGreen: Color(0xFF50FA7B),
  uiAccentYellow: Color(0xFFF1FA8C),
  uiTabTrack: Color(0xFF1D1E28),
  uiTabTrackBorder: Color(0xFF282A36),
);

static const nord = ColorTheme(
  id: 'nord',
  name: 'Nord',
  foreground: Color(0xFFECEFF4),
  background: Color(0xFF2E3440),
  cursor: Color(0xFFD8DEE9),
  selection: Color(0x60434C5E),
  black: Color(0xFF2E3440),
  red: Color(0xFFBF616A),
  green: Color(0xFFA3BE8C),
  yellow: Color(0xFFEBCB8B),
  blue: Color(0xFF81A1C1),
  magenta: Color(0xFFB48EAD),
  cyan: Color(0xFF88C0D0),
  white: Color(0xFFECEFF4),
  brightBlack: Color(0xFF4C566A),
  brightRed: Color(0xFFD08770),
  brightGreen: Color(0xFFB5CEA0),
  brightYellow: Color(0xFFF0D599),
  brightBlue: Color(0xFF8FAEC8),
  brightMagenta: Color(0xFFC298BA),
  brightCyan: Color(0xFF93CCDC),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFF444444),
  searchHitBackgroundCurrent: Color(0xFFEBCB8B),
  searchHitForeground: Color(0xFF2E3440),
  uiBackground: Color(0xFF242933),
  uiSurface: Color(0xFF2E3440),
  uiSurfaceLight: Color(0xFF3B4252),
  uiBorder: Color(0xFF434C5E),
  uiTextPrimary: Color(0xFFECEFF4),
  uiTextSecondary: Color(0xFF7B88A1),
  uiAccent: Color(0xFF88C0D0),
  uiAccentRed: Color(0xFFBF616A),
  uiAccentGreen: Color(0xFFA3BE8C),
  uiAccentYellow: Color(0xFFEBCB8B),
  uiTabTrack: Color(0xFF20242D),
  uiTabTrackBorder: Color(0xFF2E3440),
);

static const solarizedDark = ColorTheme(
  id: 'solarized-dark',
  name: 'Solarized Dark',
  foreground: Color(0xFF839496),
  background: Color(0xFF002B36),
  cursor: Color(0xFF839496),
  selection: Color(0x60073642),
  black: Color(0xFF002B36),
  red: Color(0xFFDC322F),
  green: Color(0xFF859900),
  yellow: Color(0xFFB58900),
  blue: Color(0xFF268BD2),
  magenta: Color(0xFFD33682),
  cyan: Color(0xFF2AA198),
  white: Color(0xFFEEE8D5),
  brightBlack: Color(0xFF073642),
  brightRed: Color(0xFFCB4B16),
  brightGreen: Color(0xFF586E75),
  brightYellow: Color(0xFF657B83),
  brightBlue: Color(0xFF839496),
  brightMagenta: Color(0xFF6C71C4),
  brightCyan: Color(0xFF93A1A1),
  brightWhite: Color(0xFFFDF6E3),
  searchHitBackground: Color(0xFF444444),
  searchHitBackgroundCurrent: Color(0xFFB58900),
  searchHitForeground: Color(0xFF002B36),
  uiBackground: Color(0xFF001E26),
  uiSurface: Color(0xFF002B36),
  uiSurfaceLight: Color(0xFF073642),
  uiBorder: Color(0xFF586E75),
  uiTextPrimary: Color(0xFF839496),
  uiTextSecondary: Color(0xFF657B83),
  uiAccent: Color(0xFF268BD2),
  uiAccentRed: Color(0xFFDC322F),
  uiAccentGreen: Color(0xFF859900),
  uiAccentYellow: Color(0xFFB58900),
  uiTabTrack: Color(0xFF001920),
  uiTabTrackBorder: Color(0xFF002B36),
);

static const githubDark = ColorTheme(
  id: 'github-dark',
  name: 'GitHub Dark',
  foreground: Color(0xFFE6EDF3),
  background: Color(0xFF0D1117),
  cursor: Color(0xFFE6EDF3),
  selection: Color(0x6030363D),
  black: Color(0xFF0D1117),
  red: Color(0xFFFF7B72),
  green: Color(0xFF7EE787),
  yellow: Color(0xFFE3B341),
  blue: Color(0xFF79C0FF),
  magenta: Color(0xFFD2A8FF),
  cyan: Color(0xFF56D4DD),
  white: Color(0xFFE6EDF3),
  brightBlack: Color(0xFF484F58),
  brightRed: Color(0xFFFFA198),
  brightGreen: Color(0xFFA5F0B2),
  brightYellow: Color(0xFFEAC55F),
  brightBlue: Color(0xFFA5D6FF),
  brightMagenta: Color(0xFFE2C5FF),
  brightCyan: Color(0xFF76E3EA),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFF444444),
  searchHitBackgroundCurrent: Color(0xFFE3B341),
  searchHitForeground: Color(0xFF0D1117),
  uiBackground: Color(0xFF010409),
  uiSurface: Color(0xFF0D1117),
  uiSurfaceLight: Color(0xFF161B22),
  uiBorder: Color(0xFF30363D),
  uiTextPrimary: Color(0xFFE6EDF3),
  uiTextSecondary: Color(0xFF8B949E),
  uiAccent: Color(0xFF58A6FF),
  uiAccentRed: Color(0xFFFF7B72),
  uiAccentGreen: Color(0xFF7EE787),
  uiAccentYellow: Color(0xFFE3B341),
  uiTabTrack: Color(0xFF080B10),
  uiTabTrackBorder: Color(0xFF0D1117),
);
```

- [ ] **Step 4: Verify it compiles**

Run: `cd packages/dispatch_app && flutter analyze lib/src/core/theme/color_theme.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch_app/lib/src/core/theme/color_theme.dart
git commit -m "feat(theme): add ColorTheme data class with 6 built-in palettes"
```

---

### Task 2: Add theme provider and persistence

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/settings/settings_provider.dart`
- Modify: `packages/dispatch_app/lib/src/persistence/auto_save.dart`

- [ ] **Step 1: Add ThemeNotifier and providers to settings_provider.dart**

Add at the bottom of `packages/dispatch_app/lib/src/features/settings/settings_provider.dart`:

```dart
import '../../core/theme/color_theme.dart';

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
```

- [ ] **Step 2: Add theme to auto-save in auto_save.dart**

In the `AutoSaveNotifier.build()` method, add a listener for `themeProvider`:

```dart
ref.listen(themeProvider, (_, _) => _scheduleSave());
```

In `_saveSettings()`, add after the last `setValue` call:

```dart
final themeId = ref.read(themeProvider);
await db.settingsDao.setValue('theme', themeId);
```

In `_loadSettings()`, add the theme load. After the existing `screenshotFolder` read:

```dart
final theme = await db.settingsDao.getValue('theme');
```

And after the `ref.read(settingsProvider.notifier).update(...)` call, add:

```dart
if (theme != null) {
  ref.read(themeProvider.notifier).setTheme(theme);
}
```

Also add the `import` for `settings_provider.dart`'s `themeProvider` — it's already imported since `settingsProvider` comes from the same file.

- [ ] **Step 3: Verify it compiles**

Run: `cd packages/dispatch_app && flutter analyze lib/src/features/settings/settings_provider.dart lib/src/persistence/auto_save.dart`
Expected: No errors (warnings about unused imports are OK at this stage)

- [ ] **Step 4: Commit**

```bash
git add packages/dispatch_app/lib/src/features/settings/settings_provider.dart packages/dispatch_app/lib/src/persistence/auto_save.dart
git commit -m "feat(theme): add ThemeNotifier provider with SQLite persistence"
```

---

### Task 3: Refactor AppTheme from static to instance-based

**Files:**
- Modify: `packages/dispatch_app/lib/src/core/theme/app_theme.dart`

This is the central refactor. `AppTheme` keeps its API shape but reads colors from a `ColorTheme` instance instead of hardcoded constants.

- [ ] **Step 1: Rewrite app_theme.dart**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';

import 'color_theme.dart';

class AppTheme {
  final ColorTheme colors;

  const AppTheme(this.colors);

  // Color accessors — map old static names to ColorTheme fields
  Color get background => colors.uiBackground;
  Color get surface => colors.uiSurface;
  Color get surfaceLight => colors.uiSurfaceLight;
  Color get border => colors.uiBorder;
  Color get textPrimary => colors.uiTextPrimary;
  Color get textSecondary => colors.uiTextSecondary;
  Color get accentBlue => colors.uiAccent;
  Color get accentRed => colors.uiAccentRed;
  Color get accentGreen => colors.uiAccentGreen;
  Color get accentYellow => colors.uiAccentYellow;
  Color get tabTrack => colors.uiTabTrack;
  Color get tabTrackBorder => colors.uiTabTrackBorder;

  // Non-color constants remain static
  static const fontStack = 'JetBrains Mono, Fira Code, SF Mono, Menlo, Monaco, Courier New, monospace';

  static const hoverDuration = Duration(milliseconds: 120);
  static const animDuration = Duration(milliseconds: 200);
  static const animFastDuration = Duration(milliseconds: 150);
  static const animCurve = Curves.easeOut;
  static const animCurveIn = Curves.easeIn;

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 24;
  static const double radius = 6;
  static const double tabBarHeight = 32;
  static const double terminalHeaderHeight = 24;
  static const double sidebarWidth = 180;
  static const double borderWidth = 0.5;

  // Text style presets — now instance getters since they use colors
  TextStyle get labelStyle => TextStyle(
    color: textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  TextStyle get bodyStyle => TextStyle(
    color: textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  TextStyle get titleStyle => TextStyle(
    color: textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  TextStyle get dimStyle => TextStyle(
    color: textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  BoxDecoration get overlayDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: borderWidth),
    boxShadow: const [
      BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 8)),
    ],
  );

  ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.dark(
      surface: surface,
      primary: accentBlue,
      error: accentRed,
    ),
    fontFamily: fontStack,
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
      titleSmall: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    ),
    dividerColor: border,
    iconTheme: IconThemeData(color: textSecondary, size: 16),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(4),
      radius: const Radius.circular(2),
      thumbColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.2)),
      trackColor: WidgetStateProperty.all(Colors.transparent),
      thumbVisibility: WidgetStateProperty.all(false),
    ),
  );
}
```

- [ ] **Step 2: Verify it compiles (expect downstream errors)**

Run: `cd packages/dispatch_app && flutter analyze lib/src/core/theme/app_theme.dart`
Expected: The file itself compiles. Downstream files will have errors because they still use `AppTheme.staticColor` — that's expected and fixed in Tasks 4-6.

- [ ] **Step 3: Commit**

```bash
git add packages/dispatch_app/lib/src/core/theme/app_theme.dart
git commit -m "refactor(theme): convert AppTheme from static constants to instance-based"
```

---

### Task 4: Wire theme into app.dart and create helper

**Files:**
- Modify: `packages/dispatch_app/lib/src/app.dart`

- [ ] **Step 1: Update app.dart to use the theme provider**

Add imports at the top:

```dart
import 'core/theme/color_theme.dart';
import 'features/settings/settings_provider.dart';
```

In the `build()` method of `_DispatchAppState`, create the theme instance from the provider. Add after `final hasGroups = ...`:

```dart
final colorTheme = ref.watch(activeThemeProvider);
final theme = AppTheme(colorTheme);
```

Replace both instances of `AppTheme.dark` with `theme.dark`:
- Line ~119: `theme: AppTheme.dark,` → `theme: theme.dark,`
- Line ~132: `theme: AppTheme.dark,` → `theme: theme.dark,`

In the `_TitleBar` widget, it currently uses `AppTheme.background` and `AppTheme.textSecondary` directly. Since `_TitleBar` is a plain `StatelessWidget`, it can't access Riverpod. Convert it to a `ConsumerWidget`:

```dart
class _TitleBar extends ConsumerWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme(ref.watch(activeThemeProvider));
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 38,
        color: theme.background,
        padding: const EdgeInsets.symmetric(horizontal: 80),
        child: Row(
          children: [
            Text(
              '\u2318K Search  \u2318N New',
              style: TextStyle(color: theme.textSecondary, fontSize: 11),
            ),
            const Spacer(),
            Text(
              'Dispatch',
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
            ),
            const Spacer(),
            const SizedBox(width: 120),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify app.dart compiles**

Run: `cd packages/dispatch_app && flutter analyze lib/src/app.dart`
Expected: No errors in this file

- [ ] **Step 3: Commit**

```bash
git add packages/dispatch_app/lib/src/app.dart
git commit -m "feat(theme): wire active theme provider into app.dart"
```

---

### Task 5: Update terminal_pane.dart to use theme colors

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/terminal/terminal_pane.dart`

- [ ] **Step 1: Replace hardcoded TerminalTheme with provider-driven theme**

The file already imports `settings_provider.dart`. The widget is already a `ConsumerStatefulWidget`. In the `build()` method, get the theme:

```dart
final colorTheme = ref.watch(activeThemeProvider);
final theme = AppTheme(colorTheme);
```

Replace the entire `theme: const xterm.TerminalTheme(...)` block (lines ~199-223) with:

```dart
theme: xterm.TerminalTheme(
  cursor: colorTheme.cursor,
  selection: colorTheme.selection,
  foreground: colorTheme.foreground,
  background: colorTheme.background,
  black: colorTheme.black,
  red: colorTheme.red,
  green: colorTheme.green,
  yellow: colorTheme.yellow,
  blue: colorTheme.blue,
  magenta: colorTheme.magenta,
  cyan: colorTheme.cyan,
  white: colorTheme.white,
  brightBlack: colorTheme.brightBlack,
  brightRed: colorTheme.brightRed,
  brightGreen: colorTheme.brightGreen,
  brightYellow: colorTheme.brightYellow,
  brightBlue: colorTheme.brightBlue,
  brightMagenta: colorTheme.brightMagenta,
  brightCyan: colorTheme.brightCyan,
  brightWhite: colorTheme.brightWhite,
  searchHitBackground: colorTheme.searchHitBackground,
  searchHitBackgroundCurrent: colorTheme.searchHitBackgroundCurrent,
  searchHitForeground: colorTheme.searchHitForeground,
),
```

Also replace any `AppTheme.textPrimary` / `AppTheme.accentRed` / `AppTheme.accentGreen` references in this file with `theme.textPrimary`, `theme.accentRed`, `theme.accentGreen`.

- [ ] **Step 2: Verify it compiles**

Run: `cd packages/dispatch_app && flutter analyze lib/src/features/terminal/terminal_pane.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add packages/dispatch_app/lib/src/features/terminal/terminal_pane.dart
git commit -m "feat(theme): use active theme for terminal colors"
```

---

### Task 6: Update all remaining widget files

**Files:** All 20 remaining widget files listed in the spec under "Widgets affected". Each file needs:
1. Import `settings_provider.dart` (for `activeThemeProvider`)
2. Import `app_theme.dart` (already imported in most)
3. Get theme instance: `final theme = AppTheme(ref.watch(activeThemeProvider));`
4. Replace `AppTheme.x` with `theme.x`

For widgets that are `StatelessWidget` (not `ConsumerWidget`), convert to `ConsumerWidget` and add `WidgetRef ref` to the `build` method.

This task is mechanical but touches many files. Process them in batches.

**Strategy for private nested widgets:** Many files contain private helper widgets (`_SubTab`, `_TabButton`, `_SecretItem`, etc.) that also reference `AppTheme` colors. For these, **pass the `AppTheme` instance as a constructor parameter** rather than converting every leaf widget to a `ConsumerWidget`. The parent Consumer-based widget creates the `AppTheme` and passes it down.

**Strategy for non-Consumer top-level widgets:** Some files have top-level widgets that are `StatelessWidget` or `StatefulWidget` (not Consumer-based). These include `ShortcutsPanel`, `ProjectPanel`, `BrowserConsole`, and others. Convert these to `ConsumerWidget` / `ConsumerStatefulWidget` so they can access `ref.watch(activeThemeProvider)`.

**Removing `const`:** When replacing `AppTheme.textPrimary` (static const) with `theme.textPrimary` (instance getter), remove `const` from any `TextStyle`, `BoxDecoration`, `BorderSide`, `IconThemeData`, `Text`, etc. that referenced theme colors. Instance getters are not compile-time constants.

- [ ] **Step 1: Update sidebar group (5 files)**

Update these files — for each, add the theme instance and replace static refs:
- `lib/src/features/sidebar/sidebar.dart`
- `lib/src/features/sidebar/file_tree.dart`
- `lib/src/features/sidebar/right_panel.dart`
- `lib/src/features/sidebar/terminal_list.dart`
- `lib/src/features/sidebar/status_bar.dart`

Pattern for each file:
- If widget is `ConsumerWidget` or `ConsumerStatefulWidget`: add `final theme = AppTheme(ref.watch(activeThemeProvider));` near top of `build()`
- If widget is `StatelessWidget`: convert to `ConsumerWidget`, add `WidgetRef ref` param
- Replace all `AppTheme.background` → `theme.background`, `AppTheme.surface` → `theme.surface`, etc.
- Keep `AppTheme.animDuration`, `AppTheme.spacingMd`, etc. as static (these don't change)

- [ ] **Step 2: Verify sidebar group compiles**

Run: `cd packages/dispatch_app && flutter analyze lib/src/features/sidebar/`
Expected: No errors

- [ ] **Step 3: Commit sidebar group**

```bash
git add packages/dispatch_app/lib/src/features/sidebar/
git commit -m "refactor(theme): update sidebar widgets to use theme instance"
```

- [ ] **Step 4: Update projects group (3 files)**

- `lib/src/features/projects/tab_bar.dart`
- `lib/src/features/projects/project_panel.dart`
- `lib/src/features/projects/welcome_screen.dart`

Same pattern as step 1.

- [ ] **Step 5: Verify projects group compiles**

Run: `cd packages/dispatch_app && flutter analyze lib/src/features/projects/`
Expected: No errors

- [ ] **Step 6: Commit projects group**

```bash
git add packages/dispatch_app/lib/src/features/projects/
git commit -m "refactor(theme): update project widgets to use theme instance"
```

- [ ] **Step 7: Update terminal group (3 files)**

- `lib/src/features/terminal/terminal_area.dart`
- `lib/src/features/terminal/split_container.dart`
- `lib/src/features/terminal/save_template_dialog.dart`

Same pattern.

- [ ] **Step 8: Verify terminal group compiles**

Run: `cd packages/dispatch_app && flutter analyze lib/src/features/terminal/`
Expected: No errors

- [ ] **Step 9: Commit terminal group**

```bash
git add packages/dispatch_app/lib/src/features/terminal/
git commit -m "refactor(theme): update terminal widgets to use theme instance"
```

- [ ] **Step 10: Update remaining feature files (7 files)**

- `lib/src/features/presets/quick_launch.dart`
- `lib/src/features/tasks/tasks_panel.dart`
- `lib/src/features/vault/vault_panel.dart`
- `lib/src/features/notes/notes_panel.dart`
- `lib/src/features/browser/browser_console.dart`
- `lib/src/features/browser/browser_panel.dart`
- `lib/src/features/shortcuts/shortcuts_panel.dart`

Same pattern.

- [ ] **Step 11: Verify remaining features compile**

Run: `cd packages/dispatch_app && flutter analyze lib/src/features/`
Expected: No errors

- [ ] **Step 12: Commit remaining features**

```bash
git add packages/dispatch_app/lib/src/features/
git commit -m "refactor(theme): update remaining feature widgets to use theme instance"
```

- [ ] **Step 13: Update command palette and settings panel (3 files)**

- `lib/src/features/command_palette/command_palette.dart`
- `lib/src/features/command_palette/quick_switcher.dart`
- `lib/src/features/settings/settings_panel.dart`

Same pattern. `settings_panel.dart` already imports `settings_provider.dart`.

- [ ] **Step 14: Verify command palette and settings compile**

Run: `cd packages/dispatch_app && flutter analyze lib/src/features/command_palette/ lib/src/features/settings/`
Expected: No errors

- [ ] **Step 15: Commit command palette and settings**

```bash
git add packages/dispatch_app/lib/src/features/command_palette/ packages/dispatch_app/lib/src/features/settings/
git commit -m "refactor(theme): update command palette and settings to use theme instance"
```

- [ ] **Step 16: Update test files (2 files)**

- `test/features/tab_bar_test.dart`
- `test/features/command_palette_test.dart`

These likely reference `AppTheme.someColor` in assertions or setup. Update to create an `AppTheme(ColorTheme.dispatchDark)` instance, or use `ColorTheme.dispatchDark.uiXxx` directly.

- [ ] **Step 17: Verify full project compiles**

Run: `cd packages/dispatch_app && flutter analyze`
Expected: No errors

- [ ] **Step 18: Commit test updates**

```bash
git add packages/dispatch_app/test/
git commit -m "refactor(theme): update tests for instance-based AppTheme"
```

---

### Task 7: Add theme dropdown to settings panel

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/settings/settings_panel.dart`

- [ ] **Step 1: Add theme dropdown at top of Terminal Settings section**

In the `build()` method, after creating the theme instance, read the current theme id:

```dart
final currentThemeId = ref.watch(themeProvider);
```

Add a theme dropdown row at the top of the Terminal Settings section (before the Font Family row). Note: the existing `_settingsRow` helper takes a `TextEditingController`, not a widget, so build the row inline:

```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
  child: Row(
    children: [
      SizedBox(
        width: 110,
        child: Text('Theme', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
      ),
      Expanded(
        child: DropdownButton<String>(
          value: currentThemeId,
          dropdownColor: theme.surface,
          style: TextStyle(color: theme.textPrimary, fontSize: 12),
          underline: const SizedBox.shrink(),
          isExpanded: true,
          isDense: true,
          items: ColorTheme.builtIn.map((t) => DropdownMenuItem(
            value: t.id,
            child: Text(t.name),
          )).toList(),
          onChanged: (id) {
            if (id != null) {
              ref.read(themeProvider.notifier).setTheme(id);
            }
          },
        ),
      ),
    ],
  ),
),
```

Also add the import for `ColorTheme`:

```dart
import '../../core/theme/color_theme.dart';
```

- [ ] **Step 2: Update Restore Defaults to also reset theme**

In `_restoreDefaults()`, add:

```dart
ref.read(themeProvider.notifier).setTheme('dispatch-dark');
```

- [ ] **Step 3: Verify it compiles**

Run: `cd packages/dispatch_app && flutter analyze lib/src/features/settings/settings_panel.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add packages/dispatch_app/lib/src/features/settings/settings_panel.dart
git commit -m "feat(theme): add theme dropdown to settings panel"
```

---

### Task 8: Manual smoke test

- [ ] **Step 1: Run the app**

Run: `cd packages/dispatch_app && flutter run -d macos`

- [ ] **Step 2: Verify default theme**

App should look identical to before (Dispatch Dark). No visual changes.

- [ ] **Step 3: Open settings and change theme**

Open settings panel → verify Theme dropdown appears at top → select "Dracula" → entire app (terminal + sidebar + tab bar) should change immediately.

- [ ] **Step 4: Verify persistence**

Quit and relaunch. Theme should still be Dracula.

- [ ] **Step 5: Test all 6 themes**

Cycle through all themes. Verify:
- Terminal text colors change
- Sidebar/tab bar background changes
- Status dots (running/exited) use theme accent colors
- Command palette overlay uses theme colors

- [ ] **Step 6: Test Restore Defaults**

In settings, click "Restore Defaults" → theme should revert to Dispatch Dark.
