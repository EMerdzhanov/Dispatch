# Color Themes Design Spec

## Overview

Add 6 selectable color themes to Dispatch. Each theme defines both terminal ANSI colors and UI chrome colors for a cohesive visual experience. Users pick a theme from a dropdown in the settings panel; the change applies immediately and persists across sessions.

## Decisions

- **Scope:** Terminal colors + UI chrome (full app theming)
- **Selection UI:** Dropdown in existing settings panel
- **Built-in themes:** Dispatch Dark, Monokai, Dracula, Nord, Solarized Dark, GitHub Dark
- **Custom themes:** Not supported (built-in only)
- **Apply behavior:** Immediate on selection, no save/apply button
- **Architecture:** ColorTheme data class + Riverpod provider

## Data Model

### ColorTheme class

A Dart class with named fields for every color the app uses.

**Terminal colors (23 fields):**

| Field | Description |
|-------|-------------|
| `foreground` | Default text color |
| `background` | Terminal background |
| `cursor` | Cursor color |
| `selection` | Selection highlight (with alpha ~37%) |
| `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white` | Standard ANSI colors |
| `brightBlack`, `brightRed`, `brightGreen`, `brightYellow`, `brightBlue`, `brightMagenta`, `brightCyan`, `brightWhite` | Bright ANSI variants |
| `searchHitBackground` | Background for search matches |
| `searchHitBackgroundCurrent` | Background for currently focused search match |
| `searchHitForeground` | Text color for search matches |

**UI chrome colors (12 fields):**

| Field | Description |
|-------|-------------|
| `uiBackground` | Main app background (scaffold, deepest layer) |
| `uiSurface` | Sidebar, panels |
| `uiSurfaceLight` | Elevated surfaces, hover states |
| `uiBorder` | Dividers, borders |
| `uiTextPrimary` | Primary text color |
| `uiTextSecondary` | Dimmed/secondary text |
| `uiAccent` | Active tab, selected items, links |
| `uiAccentRed` | Destructive actions, error indicators, exited terminal dots |
| `uiAccentGreen` | Success indicators, running terminal dots |
| `uiAccentYellow` | Warning indicators |
| `uiTabTrack` | Tab bar background |
| `uiTabTrackBorder` | Tab bar border |

**Identity fields:**

| Field | Description |
|-------|-------------|
| `id` | Unique string key for persistence (e.g., `'dracula'`) |
| `name` | Display name (e.g., `'Dracula'`) |

### Built-in themes as static constants

Six `ColorTheme` instances defined as `static const` on the class (the class must have a `const` constructor — Flutter's `Color` supports `const`). A `static const List<ColorTheme> builtIn` for enumeration.

## Theme Palettes

### 1. Dispatch Dark (default)

Matches the current hardcoded app colors exactly.

**Terminal:** bg `#0A0A1A`, fg `#CCCCCC`, cursor `#CCCCCC`, selection `#603A6FD6`
- black `#0A0A1A`, red `#E94560`, green `#4CAF50`, yellow `#F5A623`
- blue `#53A8FF`, magenta `#C678DD`, cyan `#56B6C2`, white `#CCCCCC`
- brightBlack `#555555`, brightRed `#FF6B81`, brightGreen `#69F0AE`
- brightYellow `#FFD740`, brightBlue `#82B1FF`, brightMagenta `#E1ACFF`
- brightCyan `#84FFFF`, brightWhite `#FFFFFF`
- searchHitBackground `#444444`, searchHitBackgroundCurrent `#FFFF00`, searchHitForeground `#000000`

**UI Chrome:** background `#0A0A1A`, surface `#12122A`, surfaceLight `#1A1A3A`, border `#2A2A4A`, textPrimary `#CCCCCC`, textSecondary `#888888`, accent `#3A6FD6`, accentRed `#E94560`, accentGreen `#00CD00`, accentYellow `#F5A623`, tabTrack `#060612`, tabTrackBorder `#1A1A2A`

### 2. Monokai

**Terminal:** bg `#272822`, fg `#F8F8F2`, cursor `#F8F8F0`, selection `#6049483E`
- black `#272822`, red `#F92672`, green `#A6E22E`, yellow `#E6DB74`
- blue `#66D9EF`, magenta `#AE81FF`, cyan `#A1EFE4`, white `#F8F8F2`
- brightBlack `#75715E`, brightRed `#F44747`, brightGreen `#B5F76C`
- brightYellow `#F3EDA5`, brightBlue `#8DE8FC`, brightMagenta `#C7A5FF`
- brightCyan `#B5F7EF`, brightWhite `#F9F8F5`
- searchHitBackground `#444444`, searchHitBackgroundCurrent `#E6DB74`, searchHitForeground `#272822`

**UI Chrome:** background `#1E1F1C`, surface `#272822`, surfaceLight `#3E3D32`, border `#49483E`, textPrimary `#F8F8F2`, textSecondary `#75715E`, accent `#F92672`, accentRed `#F92672`, accentGreen `#A6E22E`, accentYellow `#E6DB74`, tabTrack `#1A1B18`, tabTrackBorder `#272822`

### 3. Dracula

**Terminal:** bg `#282A36`, fg `#F8F8F2`, cursor `#F8F8F2`, selection `#6044475A`
- black `#282A36`, red `#FF5555`, green `#50FA7B`, yellow `#F1FA8C`
- blue `#BD93F9`, magenta `#FF79C6`, cyan `#8BE9FD`, white `#F8F8F2`
- brightBlack `#6272A4`, brightRed `#FF6E6E`, brightGreen `#69FF94`
- brightYellow `#FFFFA5`, brightBlue `#D6ACFF`, brightMagenta `#FF92DF`
- brightCyan `#A4FFFF`, brightWhite `#FFFFFF`
- searchHitBackground `#444444`, searchHitBackgroundCurrent `#F1FA8C`, searchHitForeground `#282A36`

**UI Chrome:** background `#21222C`, surface `#282A36`, surfaceLight `#343746`, border `#44475A`, textPrimary `#F8F8F2`, textSecondary `#6272A4`, accent `#BD93F9`, accentRed `#FF5555`, accentGreen `#50FA7B`, accentYellow `#F1FA8C`, tabTrack `#1D1E28`, tabTrackBorder `#282A36`

### 4. Nord

**Terminal:** bg `#2E3440`, fg `#ECEFF4`, cursor `#D8DEE9`, selection `#60434C5E`
- black `#2E3440`, red `#BF616A`, green `#A3BE8C`, yellow `#EBCB8B`
- blue `#81A1C1`, magenta `#B48EAD`, cyan `#88C0D0`, white `#ECEFF4`
- brightBlack `#4C566A`, brightRed `#D08770`, brightGreen `#B5CEA0`
- brightYellow `#F0D599`, brightBlue `#8FAEC8`, brightMagenta `#C298BA`
- brightCyan `#93CCDC`, brightWhite `#FFFFFF`
- searchHitBackground `#444444`, searchHitBackgroundCurrent `#EBCB8B`, searchHitForeground `#2E3440`

> Note: `brightRed` uses Nord's orange (`nord12` / `#D08770`) — this is a common terminal mapping since Nord lacks a distinct bright red.

**UI Chrome:** background `#242933`, surface `#2E3440`, surfaceLight `#3B4252`, border `#434C5E`, textPrimary `#ECEFF4`, textSecondary `#7B88A1`, accent `#88C0D0`, accentRed `#BF616A`, accentGreen `#A3BE8C`, accentYellow `#EBCB8B`, tabTrack `#20242D`, tabTrackBorder `#2E3440`

### 5. Solarized Dark

**Terminal:** bg `#002B36`, fg `#839496`, cursor `#839496`, selection `#60073642`
- black `#002B36`, red `#DC322F`, green `#859900`, yellow `#B58900`
- blue `#268BD2`, magenta `#D33682`, cyan `#2AA198`, white `#EEE8D5`
- brightBlack `#073642`, brightRed `#CB4B16`, brightGreen `#586E75`
- brightYellow `#657B83`, brightBlue `#839496`, brightMagenta `#6C71C4`
- brightCyan `#93A1A1`, brightWhite `#FDF6E3`
- searchHitBackground `#444444`, searchHitBackgroundCurrent `#B58900`, searchHitForeground `#002B36`

> Note: Solarized maps some bright colors to its base gray tones (`brightGreen` = `base01`, `brightYellow` = `base00`). This is standard Solarized behavior, not a mistake.

**UI Chrome:** background `#001E26`, surface `#002B36`, surfaceLight `#073642`, border `#586E75`, textPrimary `#839496`, textSecondary `#657B83`, accent `#268BD2`, accentRed `#DC322F`, accentGreen `#859900`, accentYellow `#B58900`, tabTrack `#001920`, tabTrackBorder `#002B36`

### 6. GitHub Dark

**Terminal:** bg `#0D1117`, fg `#E6EDF3`, cursor `#E6EDF3`, selection `#6030363D`
- black `#0D1117`, red `#FF7B72`, green `#7EE787`, yellow `#E3B341`
- blue `#79C0FF`, magenta `#D2A8FF`, cyan `#56D4DD`, white `#E6EDF3`
- brightBlack `#484F58`, brightRed `#FFA198`, brightGreen `#A5F0B2`
- brightYellow `#EAC55F`, brightBlue `#A5D6FF`, brightMagenta `#E2C5FF`
- brightCyan `#76E3EA`, brightWhite `#FFFFFF`
- searchHitBackground `#444444`, searchHitBackgroundCurrent `#E3B341`, searchHitForeground `#0D1117`

**UI Chrome:** background `#010409`, surface `#0D1117`, surfaceLight `#161B22`, border `#30363D`, textPrimary `#E6EDF3`, textSecondary `#8B949E`, accent `#58A6FF`, accentRed `#FF7B72`, accentGreen `#7EE787`, accentYellow `#E3B341`, tabTrack `#080B10`, tabTrackBorder `#0D1117`

## State Management & Persistence

### Provider

- `themeProvider` — `NotifierProvider<ThemeNotifier, String>` holding the active theme `id` (uses the `Notifier` pattern to match existing `SettingsNotifier`)
- `activeThemeProvider` — computed `Provider<ColorTheme>` that maps the id to the corresponding `ColorTheme` constant
- Default value: `'dispatch-dark'`

### Persistence

- Stored in SQLite via existing `SettingsDao.setValue('theme', id)`
- Loaded on app startup in `loadSavedState()` — reads `'theme'` key, falls back to `'dispatch-dark'`
- Auto-saved via existing debounced auto-save mechanism

## AppTheme Refactor

Currently `AppTheme` is a static class with hardcoded color constants. It must become dynamic:

- `AppTheme` gets a constructor that accepts a `ColorTheme` instance
- Static color constants become instance getters that read from the `ColorTheme`
- Non-color static members (`fontStack`, spacing, animation durations/curves) remain static — they don't vary by theme
- `TextStyle` presets (`labelStyle`, `bodyStyle`, `titleStyle`, `dimStyle`) must become instance getters since they reference color fields
- `overlayDecoration` must become an instance getter since it references colors
- `ThemeData get dark` becomes parameterized by the active `ColorTheme`
- All widgets referencing `AppTheme.someColor` are updated to read from the theme instance

### Widgets affected (25 files)

- `app.dart` — `MaterialApp` theme
- `terminal_pane.dart` — builds `TerminalTheme` from active `ColorTheme`
- `terminal_area.dart` — tabTrackBorder
- `terminal_list.dart` — status dot colors, text
- `split_container.dart` — divider colors
- `sidebar.dart` — background, border
- `file_tree.dart` — text, icon colors
- `right_panel.dart` — border, tabTrackBorder
- `status_bar.dart` — background, text
- `tab_bar.dart` — tab track, border, active tab
- `project_panel.dart` — border, tabTrackBorder
- `welcome_screen.dart` — background, text
- `settings_panel.dart` — panel styling, input decor
- `quick_launch.dart` — preset button colors
- `tasks_panel.dart` — panel colors
- `vault_panel.dart` — panel colors
- `notes_panel.dart` — panel colors
- `browser_console.dart` — accent colors for errors/warnings
- `browser_panel.dart` — panel colors
- `shortcuts_panel.dart` — panel colors
- `save_template_dialog.dart` — dialog styling
- `command_palette.dart` — overlay colors
- `quick_switcher.dart` — status dot colors
- `test/features/tab_bar_test.dart` — test references
- `test/features/command_palette_test.dart` — test references

## Settings UI

- Add a "Theme" row at the top of the Terminal Settings section in `settings_panel.dart`
- Widget: styled `DropdownButton<String>` matching existing input styling
- Lists all 6 themes by display name
- Selection immediately updates `themeProvider`
- No preview pane, no color swatches — just the dropdown

## Files to Create

| File | Purpose |
|------|---------|
| `lib/src/core/theme/color_theme.dart` | `ColorTheme` class + 6 built-in theme constants |

## Files to Modify

**Core changes:**

| File | Change |
|------|--------|
| `lib/src/core/theme/app_theme.dart` | Refactor from static constants to instance reading from `ColorTheme` |
| `lib/src/features/settings/settings_provider.dart` | Add `themeProvider` and `activeThemeProvider` |
| `lib/src/features/settings/settings_panel.dart` | Add theme dropdown row |
| `lib/src/features/terminal/terminal_pane.dart` | Build `TerminalTheme` from active `ColorTheme` |
| `lib/src/persistence/auto_save.dart` | Add theme to save/load cycle |
| `lib/src/app.dart` | Wire `ThemeData` to active theme |

**Widget updates (replace `AppTheme.x` with theme instance):**

| File | Change |
|------|--------|
| `lib/src/features/sidebar/sidebar.dart` | background, border |
| `lib/src/features/sidebar/file_tree.dart` | text, icon colors |
| `lib/src/features/sidebar/right_panel.dart` | border, tabTrackBorder |
| `lib/src/features/sidebar/terminal_list.dart` | status dots, text |
| `lib/src/features/sidebar/status_bar.dart` | background, text |
| `lib/src/features/projects/tab_bar.dart` | tab track, border |
| `lib/src/features/projects/project_panel.dart` | border, tabTrackBorder |
| `lib/src/features/projects/welcome_screen.dart` | background, text |
| `lib/src/features/terminal/terminal_area.dart` | tabTrackBorder |
| `lib/src/features/terminal/split_container.dart` | divider colors |
| `lib/src/features/terminal/save_template_dialog.dart` | dialog styling |
| `lib/src/features/presets/quick_launch.dart` | preset button colors |
| `lib/src/features/tasks/tasks_panel.dart` | panel colors |
| `lib/src/features/vault/vault_panel.dart` | panel colors |
| `lib/src/features/notes/notes_panel.dart` | panel colors |
| `lib/src/features/browser/browser_console.dart` | accent colors |
| `lib/src/features/browser/browser_panel.dart` | panel colors |
| `lib/src/features/shortcuts/shortcuts_panel.dart` | panel colors |
| `lib/src/features/command_palette/command_palette.dart` | overlay colors |
| `lib/src/features/command_palette/quick_switcher.dart` | status dots |
| `test/features/tab_bar_test.dart` | test references |
| `test/features/command_palette_test.dart` | test references |

## Out of Scope

- Custom user-defined themes
- Theme import/export
- Per-terminal themes
- Light themes
- UI animation on theme switch
