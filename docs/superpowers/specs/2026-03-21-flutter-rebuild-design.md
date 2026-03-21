# Dispatch Flutter Rebuild — Design Spec

## Overview

Rebuild Dispatch (an Electron-based desktop terminal manager for Claude Code) as a native Flutter desktop application targeting macOS. The primary motivation is performance — eliminating Electron's Chromium overhead for a terminal-heavy app.

The rebuild preserves the existing feature set with the exception of tmux integration and the embedded browser panel, which are deferred to post-v1.

## Architecture: Core + Shell

The project is a Melos monorepo with two packages:

- **`dispatch_terminal`** — A standalone Dart/Flutter package containing the terminal emulation engine. No app-level dependencies. Testable and reusable in isolation.
- **`dispatch_app`** — The Flutter desktop application that composes the terminal engine with UI, state management, and persistence.

### Project Structure

```
dispatch/
├── melos.yaml
├── packages/
│   ├── dispatch_terminal/
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── vt_parser.dart
│   │   │   │   ├── screen_buffer.dart
│   │   │   │   ├── terminal_renderer.dart
│   │   │   │   ├── pty_ffi.dart
│   │   │   │   ├── pty_manager.dart
│   │   │   │   └── terminal_widget.dart
│   │   │   └── dispatch_terminal.dart
│   │   └── test/
│   └── dispatch_app/
│       ├── lib/
│       │   ├── src/
│       │   │   ├── features/
│       │   │   │   ├── terminal/
│       │   │   │   ├── projects/
│       │   │   │   ├── presets/
│       │   │   │   ├── browser/
│       │   │   │   ├── notes/
│       │   │   │   ├── tasks/
│       │   │   │   ├── vault/
│       │   │   │   ├── settings/
│       │   │   │   └── command_palette/
│       │   │   ├── core/
│       │   │   │   ├── database/
│       │   │   │   ├── theme/
│       │   │   │   ├── shortcuts/
│       │   │   │   └── router.dart
│       │   │   └── app.dart
│       │   └── main.dart
│       └── test/
```

## Terminal Engine (`dispatch_terminal`)

### VT Parser

A state machine that processes incoming byte streams from the PTY and emits structured actions (print character, move cursor, set color, scroll, etc.). Follows the VT100/xterm specification.

- Pure Dart, no Flutter dependency
- Input: raw bytes from PTY
- Output: structured action objects (PrintChar, MoveCursor, SetColor, Scroll, etc.)
- Handles partial sequences (bytes may arrive split across reads)
- Supports: cursor movement, SGR attributes (colors, bold, italic, underline), scrolling regions, erase operations, alternate screen buffer switching, window title changes

### Screen Buffer

A character grid (cols x rows) plus a scrollback buffer. Each cell holds:
- Character (Unicode codepoint)
- Foreground color (256-color + 24-bit truecolor)
- Background color (256-color + 24-bit truecolor)
- Attributes (bold, italic, underline, blink, inverse, strikethrough)

Features:
- Primary and alternate screen buffers (for vim, less, etc.)
- Scrollback history (configurable, default 5000 lines)
- Selection model for copy/paste
- Line wrapping tracking
- Trims oldest lines when scrollback limit is reached (no unbounded memory growth)

### PTY FFI Bridge

Dart FFI bindings (`dart:ffi`) to POSIX PTY functions:
- `forkpty()` — create a pseudoterminal and fork a child process
- `read()` / `write()` — stream data to/from the PTY file descriptor
- `ioctl()` with `TIOCSWINSZ` — resize the terminal
- `waitpid()` — detect child process exit
- `kill()` — send signals (SIGTERM, SIGKILL)

Each PTY runs on its own Dart Isolate to avoid blocking the UI thread. The isolate holds the file descriptor and runs a read loop, sending data chunks to the main isolate via `SendPort`. Write commands are sent from the main isolate to the PTY isolate via `ReceivePort`.

### Terminal Renderer

A `CustomPainter` that renders the screen buffer onto a Flutter `Canvas`.

- Draws character grid with proper font metrics
- Supports 256-color and truecolor (24-bit) rendering
- Bold, italic, underline attribute rendering
- Cursor rendering with configurable blink
- Selection highlighting for copy operations
- Efficient rendering — only repaints dirty regions when possible

### Terminal Widget (Public API)

A `StatefulWidget` that composes the renderer with input handling:

```dart
TerminalView(
  pty: ptyInstance,
  fontSize: 13,
  fontFamily: 'JetBrains Mono',
  theme: TerminalTheme.dark,
  onTitle: (title) => updateTabTitle(title),
)
```

Responsibilities:
- Keyboard events → byte sequences → PTY writes
- Mouse events → selection, scrolling
- Focus management
- Resize detection → PTY resize via ioctl

## App Shell (`dispatch_app`)

### State Management: Riverpod

All app state lives in Riverpod providers. Widgets observe providers and never talk to PTY or database directly.

Key providers:
- `projectGroupsProvider` — groups, active group, tab order
- `terminalsProvider` — terminal entries, statuses, active terminal ID
- `splitLayoutProvider` — per-group split tree (binary tree of leaf/branch nodes)
- `presetsProvider` — quick-launch presets
- `settingsProvider` — app settings, keybindings
- `projectDataProvider` — notes, tasks, vault (scoped to active project)

### Persistence: SQLite via drift

Single database file at `~/.config/dispatch/dispatch.db`.

Tables:
- `project_groups` — id, label, cwd, display order
- `presets` — name, command, color, icon, env (JSON)
- `settings` — key/value pairs
- `templates` — name, cwd, layout (JSON-encoded split tree)
- `notes` — project_cwd, title, body, updated_at
- `tasks` — project_cwd, title, description, done
- `vault_entries` — project_cwd, label, encrypted_value

Auto-save: Riverpod state changes trigger a debounced (2-second) write to SQLite via drift. Non-blocking, runs async.

### Features

**Project Groups & Tabs** — Tab bar across the top. Each tab is a project group identified by folder path. Groups own terminal IDs, split layouts. Drag-to-reorder tabs. "Open Folder" creates a new group.

**Split Panes** — Binary tree model (`SplitNode` = leaf | branch). `SplitContainer` widget recursively renders the tree with draggable dividers. `Cmd+D` for horizontal splits, `Cmd+Shift+D` for vertical, `Cmd+W` exits split view.

**Quick-Launch Presets** — Sidebar panel with preset buttons. Default presets: Claude Code, Resume Session, Skip Permissions, Shell. Stored in SQLite. Custom presets with name, command, color, icon, optional env vars.

**Command Palette** — `Cmd+Shift+P` opens floating overlay with fuzzy search over actions. Native Dart fuzzy matching (scored substring).

**Quick Switcher** — `Cmd+K` opens fuzzy search over terminals. Navigate and switch with keyboard.

**Sidebar** — Terminal list, presets panel, file tree. Resizable width. Hidden in zen mode.

**Notes** — Per-project markdown notes. Title + body + timestamp. CRUD via sidebar panel.

**Tasks** — Per-project task list. Title + description + done boolean. Toggle completion, add/remove.

**Vault** — Per-project encrypted secrets. Label + encrypted value. Encryption using a machine-derived key.

**Settings Panel** — Overlay panel for: shell path, font family, font size, line height, notification preferences, screenshot folder, keybinding customization.

**Keyboard Shortcuts** — Uses Flutter's `Shortcuts` + `Actions` widget system. Customizable keybindings stored in settings. Shortcuts panel to view and modify bindings.

**Zen Mode** — `Cmd+Shift+Z` hides sidebar for focused terminal work.

**Session Templates** — Save current group layout (split tree + commands) as a named template. Restore templates from welcome screen or command palette.

**Desktop Notifications** — macOS native notifications for task completion and error detection. Controlled by settings toggle.

**Terminal Activity Monitoring** — Watches PTY output for patterns indicating idle, running, success, or error states. Updates terminal status indicators in the sidebar.

**Localhost URL Detection** — Watches PTY output for `localhost:XXXX` patterns. Opens detected URLs in the system browser (no embedded browser panel in v1).

### UI & Theme

- Dark theme: `#0a0a1a` background, accent blues and reds matching current app
- macOS `hiddenInset` title bar style via `macos_window_utils` or `window_manager`
- Title bar drag region with keyboard hints
- Monospace font for terminal, system font for UI elements

## Data Flow

### Keystroke → Shell
1. Flutter `KeyEvent` captured by `TerminalView`
2. Mapped to byte sequence (e.g. Enter → `\r`, arrow keys → escape sequences)
3. Sent to PTY isolate via `SendPort`
4. Written to PTY fd via FFI `write()`
5. Shell processes input, echoes response
6. PTY isolate reads response via FFI `read()`
7. Data sent to main isolate via `SendPort`
8. VT parser processes bytes → actions → screen buffer mutations → `CustomPainter` repaint

### Spawn Terminal
1. User clicks preset or `Cmd+N`
2. `terminalsProvider.spawn(cwd, command)` called
3. `PtyManager.spawn()` creates new isolate, calls `forkpty()` via FFI
4. Returns terminal ID
5. Provider state updated → UI rebuilds with new terminal pane
6. `TerminalView` widget connects to PTY data stream

### Auto-Save
1. Riverpod provider state changes
2. Debounced listener (2 seconds) triggers save
3. drift writes changed state to SQLite asynchronously
4. No UI thread blocking

## Error Handling

**PTY spawn failure** — If `forkpty()` fails (e.g. fd limit), spawn returns error state. UI shows inline error in terminal pane with "Retry" button. Terminal entry gets `EXITED` status.

**Isolate crash** — If a PTY isolate dies, main isolate's `ReceivePort` closes. Terminal marked as `EXITED`, resources cleaned up. No cascading failures (isolates are independent).

**Corrupt database** — On startup, if drift cannot open the DB, back up as `dispatch.db.bak` and create fresh. User loses settings but avoids silent crash.

**Invalid CWD** — If project folder no longer exists at spawn time, fall back to `$HOME`. Show toast notification.

**Resize sequencing** — Resize always follows: FFI `ioctl()` call → buffer resize → repaint. Executed on main isolate, no race conditions.

## Testing Strategy

### `dispatch_terminal`

- **VT Parser** — Pure unit tests. Byte sequences in, actions out. Cover common sequences, edge cases (malformed, partial, UTF-8 multibyte).
- **Screen Buffer** — Unit tests. Apply actions, assert grid state. Scrollback, wrapping, cursor, erase.
- **PTY FFI** — Integration tests. Spawn real shell, write command, assert output. Resize, exit, signals. Separated due to slower execution.
- **Terminal Widget** — Widget tests with mock PTY (in-memory stream). Rendering, input mapping, selection, scrolling.

### `dispatch_app`

- **Providers** — Unit tests with `ProviderContainer`. State transitions: spawn, switch group, add preset, save template.
- **Database** — Unit tests with in-memory SQLite via drift. CRUD for each table, migrations, reactive queries.
- **Widgets** — Widget tests for key interactions: tab reorder, split divider drag, command palette search, settings panel.
- **Integration** — Golden tests for main layouts: welcome screen, single terminal, split view.

### Tools

- `flutter_test` + `flutter_riverpod` testing utilities
- drift in-memory database for DB tests
- `mocktail` for mocking (minimal — prefer real implementations)

## v1 Scope

### Included
- Custom terminal engine (VT parser, screen buffer, canvas renderer, PTY FFI)
- Project groups with tab bar
- Split panes (horizontal/vertical)
- Quick-launch presets
- Command palette and quick switcher
- Sidebar (terminal list, presets, file tree)
- Per-project notes, tasks, vault (SQLite)
- Settings panel
- Customizable keyboard shortcuts
- Zen mode
- Session templates
- Desktop notifications
- Terminal activity monitoring
- Dark theme
- macOS only, `hiddenInset` title bar

### Deferred (post-v1)
- tmux integration (session persistence, resume, external session detection)
- Built-in browser panel (embedded localhost preview)
- Process scanner (external terminal session detection)
- Linux support
- Sound notifications

### Partial (v1)
- Localhost URL detection — detects URLs in terminal output, opens in system browser instead of embedded panel

## Dependencies

### `dispatch_terminal`
- `dart:ffi` (stdlib)
- `ffi` package (for C type helpers)

### `dispatch_app`
- `flutter_riverpod` — state management
- `drift` + `sqlite3_flutter_libs` — SQLite persistence
- `window_manager` — window title bar, size, position
- `mocktail` (dev) — mocking
- `flutter_test` (dev) — testing

### Monorepo
- `melos` — package linking, scripts, test orchestration

## Platform

- macOS only (v1)
- Minimum macOS version: 12.0 (Monterey)
- Flutter stable channel
- Dart 3.x
