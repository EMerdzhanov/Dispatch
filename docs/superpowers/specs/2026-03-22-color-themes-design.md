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

**Terminal colors (20 fields):**

| Field | Description |
|-------|-------------|
| `foreground` | Default text color |
| `background` | Terminal background |
| `cursor` | Cursor color |
| `selection` | Selection highlight (with alpha) |
| `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white` | Standard ANSI colors |
| `brightBlack`, `brightRed`, `brightGreen`, `brightYellow`, `brightBlue`, `brightMagenta`, `brightCyan`, `brightWhite` | Bright ANSI variants |

**UI chrome colors (8 fields):**

| Field | Description |
|-------|-------------|
| `uiBackground` | Main app background (scaffold, deepest layer) |
| `uiSurface` | Sidebar, panels |
| `uiSurfaceLight` | Elevated surfaces, hover states |
| `uiBorder` | Dividers, borders |
| `uiTextPrimary` | Primary text color |
| `uiTextSecondary` | Dimmed/secondary text |
| `uiAccent` | Active tab, selected items, links |
| `uiTabTrack` | Tab bar background |

**Identity fields:**

| Field | Description |
|-------|-------------|
| `id` | Unique string key for persistence (e.g., `'dracula'`) |
| `name` | Display name (e.g., `'Dracula'`) |

### Built-in themes as static constants

Six `ColorTheme` instances defined as `static const` on the class. A `static const List<ColorTheme> builtIn` for enumeration.

## Theme Palettes

### 1. Dispatch Dark (default)

**Terminal:** bg `#0A0A1A`, fg `#CCCCCC`, cursor `#CCCCCC`
- black `#0A0A1A`, red `#E94560`, green `#4CAF50`, yellow `#F5A623`
- blue `#53A8FF`, magenta `#C678DD`, cyan `#56B6C2`, white `#CCCCCC`
- brightBlack `#555577`, brightRed `#FF6B81`, brightGreen `#69F0AE`
- brightYellow `#FFD54F`, brightBlue `#82B1FF`, brightMagenta `#DA9EF5`
- brightCyan `#7FDBCA`, brightWhite `#FFFFFF`

**UI Chrome:** background `#0A0A1A`, surface `#12122A`, surfaceLight `#1A1A3A`, border `#2A2A4A`, textPrimary `#CCCCCC`, textSecondary `#888888`, accent `#3A6FD6`, tabTrack `#060612`

### 2. Monokai

**Terminal:** bg `#272822`, fg `#F8F8F2`, cursor `#F8F8F0`
- black `#272822`, red `#F92672`, green `#A6E22E`, yellow `#E6DB74`
- blue `#66D9EF`, magenta `#AE81FF`, cyan `#A1EFE4`, white `#F8F8F2`
- brightBlack `#75715E`, brightRed `#F44747`, brightGreen `#B5F76C`
- brightYellow `#F3EDA5`, brightBlue `#8DE8FC`, brightMagenta `#C7A5FF`
- brightCyan `#B5F7EF`, brightWhite `#F9F8F5`

**UI Chrome:** background `#1E1F1C`, surface `#272822`, surfaceLight `#3E3D32`, border `#49483E`, textPrimary `#F8F8F2`, textSecondary `#75715E`, accent `#F92672`, tabTrack `#1A1B18`

### 3. Dracula

**Terminal:** bg `#282A36`, fg `#F8F8F2`, cursor `#F8F8F2`
- black `#282A36`, red `#FF5555`, green `#50FA7B`, yellow `#F1FA8C`
- blue `#BD93F9`, magenta `#FF79C6`, cyan `#8BE9FD`, white `#F8F8F2`
- brightBlack `#6272A4`, brightRed `#FF6E6E`, brightGreen `#69FF94`
- brightYellow `#FFFFA5`, brightBlue `#D6ACFF`, brightMagenta `#FF92DF`
- brightCyan `#A4FFFF`, brightWhite `#FFFFFF`

**UI Chrome:** background `#21222C`, surface `#282A36`, surfaceLight `#343746`, border `#44475A`, textPrimary `#F8F8F2`, textSecondary `#6272A4`, accent `#BD93F9`, tabTrack `#1D1E28`

### 4. Nord

**Terminal:** bg `#2E3440`, fg `#ECEFF4`, cursor `#D8DEE9`
- black `#2E3440`, red `#BF616A`, green `#A3BE8C`, yellow `#EBCB8B`
- blue `#81A1C1`, magenta `#B48EAD`, cyan `#88C0D0`, white `#ECEFF4`
- brightBlack `#4C566A`, brightRed `#D08770`, brightGreen `#B5CEA0`
- brightYellow `#F0D599`, brightBlue `#8FAEC8`, brightMagenta `#C298BA`
- brightCyan `#93CCDC`, brightWhite `#FFFFFF`

**UI Chrome:** background `#242933`, surface `#2E3440`, surfaceLight `#3B4252`, border `#434C5E`, textPrimary `#ECEFF4`, textSecondary `#7B88A1`, accent `#88C0D0`, tabTrack `#20242D`

### 5. Solarized Dark

**Terminal:** bg `#002B36`, fg `#839496`, cursor `#839496`
- black `#002B36`, red `#DC322F`, green `#859900`, yellow `#B58900`
- blue `#268BD2`, magenta `#D33682`, cyan `#2AA198`, white `#EEE8D5`
- brightBlack `#073642`, brightRed `#CB4B16`, brightGreen `#586E75`
- brightYellow `#657B83`, brightBlue `#839496`, brightMagenta `#6C71C4`
- brightCyan `#93A1A1`, brightWhite `#FDF6E3`

**UI Chrome:** background `#001E26`, surface `#002B36`, surfaceLight `#073642`, border `#586E75`, textPrimary `#839496`, textSecondary `#657B83`, accent `#268BD2`, tabTrack `#001920`

### 6. GitHub Dark

**Terminal:** bg `#0D1117`, fg `#E6EDF3`, cursor `#E6EDF3`
- black `#0D1117`, red `#FF7B72`, green `#7EE787`, yellow `#E3B341`
- blue `#79C0FF`, magenta `#D2A8FF`, cyan `#56D4DD`, white `#E6EDF3`
- brightBlack `#484F58`, brightRed `#FFA198`, brightGreen `#A5F0B2`
- brightYellow `#EAC55F`, brightBlue `#A5D6FF`, brightMagenta `#E2C5FF`
- brightCyan `#76E3EA`, brightWhite `#FFFFFF`

**UI Chrome:** background `#010409`, surface `#0D1117`, surfaceLight `#161B22`, border `#30363D`, textPrimary `#E6EDF3`, textSecondary `#8B949E`, accent `#58A6FF`, tabTrack `#080B10`

## State Management & Persistence

### Provider

- `themeProvider` — `StateNotifierProvider<ThemeNotifier, String>` holding the active theme `id`
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
- `ThemeData get dark` becomes parameterized by the active `ColorTheme`
- All widgets referencing `AppTheme.someColor` are updated to read from the theme instance

### Widgets affected

- `sidebar.dart` — background, border colors
- `tab_bar.dart` — tab track, border, active tab colors
- `terminal_pane.dart` — builds `TerminalTheme` from active `ColorTheme`
- `settings_panel.dart` — panel background, text colors, input styling
- `app.dart` — `MaterialApp` theme
- `file_tree.dart` — text and icon colors
- `terminal_list.dart` — list item colors
- Any other widget using `AppTheme` constants

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

| File | Change |
|------|--------|
| `lib/src/core/theme/app_theme.dart` | Refactor from static constants to instance reading from `ColorTheme` |
| `lib/src/features/settings/settings_provider.dart` | Add `themeProvider` and `activeThemeProvider` |
| `lib/src/features/settings/settings_panel.dart` | Add theme dropdown row |
| `lib/src/features/terminal/terminal_pane.dart` | Build `TerminalTheme` from active `ColorTheme` |
| `lib/src/persistence/auto_save.dart` | Add theme to save/load cycle |
| `lib/src/app.dart` | Wire `ThemeData` to active theme |
| `lib/src/features/sidebar/sidebar.dart` | Use theme instance colors |
| `lib/src/features/projects/tab_bar.dart` | Use theme instance colors |
| `lib/src/features/sidebar/file_tree.dart` | Use theme instance colors |
| `lib/src/features/sidebar/terminal_list.dart` | Use theme instance colors |

## Out of Scope

- Custom user-defined themes
- Theme import/export
- Per-terminal themes
- Light themes
- UI animation on theme switch
