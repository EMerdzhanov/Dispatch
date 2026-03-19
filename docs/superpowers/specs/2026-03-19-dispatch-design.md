# Dispatch — Design Spec

A desktop terminal manager for Claude Code power users. Groups terminals by project, provides quick-launch presets, detects and attaches to external terminal sessions, and offers full keyboard + mouse navigation. Mac + Linux only.

## Problem

Developers using Claude Code across many projects accumulate dozens of terminal windows spread across multiple apps (iTerm, Terminal.app, VS Code, etc.). Navigating between them is slow and context-switching is painful. There's no centralized view of what's running where.

## Solution

Dispatch is a standalone desktop app (Electron) that acts as a terminal hub:

- All terminals in one window, grouped by project
- One-click preset commands to launch Claude Code sessions
- Detects and adopts terminals opened in other apps
- Full keyboard and mouse navigation
- Remembers layout across restarts

## UI Layout

### Top Tab Bar

- One tab per project group
- Folder-based tabs auto-created when spawning a terminal in a directory not associated with any existing tab. Tab association is based on the initial CWD at spawn time, not the terminal's current working directory.
- Custom groups created via "+" button (for cross-directory task grouping)
- Tabs show folder name (e.g. `~/Projects/dispatch`) or custom label (e.g. "DevOps Tasks")
- Active tab highlighted with accent color border
- Tabs can be reordered via drag-and-drop
- `Cmd+1-9` to switch by position, `Cmd+Shift+]`/`[` to cycle

### Left Sidebar

Two zones stacked vertically:

**Quick Launch (top):** Compact preset buttons. Each shows the preset name with its assigned color. Click a preset to spawn a terminal with that command in the current project's directory. This is the primary mouse-driven way to launch presets. The command palette (`Cmd+Shift+P`) provides the same functionality via keyboard with fuzzy search.

**Terminal List (bottom):** All terminals in the active project tab. Includes a filter input at the top for narrowing the list when many terminals are open. Each entry shows:
- Terminal type (Claude Code / Shell)
- Running command (truncated)
- Status badge: ACTIVE (focused), RUNNING (background), EXITED (process ended), EXTERNAL (detected from another app), ATTACHING (tmux attach in progress)
- Active terminal highlighted with accent-color left border
- Terminals can be dragged between project groups

**Status Bar (bottom edge):** Terminal count and external terminal count for the current project.

### Main Terminal Area

- Full xterm.js terminal filling the remaining space
- Header bar showing terminal context (type, CWD) and contextual shortcuts
- Supports split panes: horizontal (`Cmd+D`) and vertical (`Cmd+Shift+D`)
- Splits are UI-level (separate xterm.js instances), not tmux splits
- Split pane dividers are draggable to resize
- `Cmd+Alt+Arrow` to move focus between panes
- `Cmd+Shift+Enter` to maximize/restore current terminal (zen mode)

## Architecture

### Layer 1: Electron Shell

- Main process: window management, menus, global shortcuts, app lifecycle
- Renderer process: React UI + xterm.js terminals
- IPC bridge (contextBridge) for secure main↔renderer communication

### Layer 2: PTY Manager (main process)

- Uses `node-pty` to spawn and manage terminal sessions
- Each terminal gets a PTY instance with configurable shell, CWD, and initial command
- Handles resize events and bidirectional data streaming to xterm.js
- Emits `pty:exit` events when a terminal process ends (exit code + signal)
- For external terminal adoption: integrates with tmux to attach to existing sessions

**Terminal exit behavior:** When a terminal's process exits, the pane remains open showing the exit status (exit code and signal). The user can press any key to close the pane, or click "Restart" to re-run the same command. This is important for Claude Code sessions that finish and exit.

**Error handling:**
- If `node-pty` fails to spawn (e.g. shell not found): show an error message in the terminal pane with the failure reason, fall back to the system default shell (`$SHELL` or `/bin/sh`)
- If a saved CWD no longer exists on disk: fall back to the user's home directory, show a notification explaining the fallback

### Layer 3: Session Store

- JSON files at `~/.config/dispatch/`:
  - `state.json` — project groups (tabs), terminal entries per group (command, CWD, position), sidebar layout, window geometry
  - `presets.json` — command presets
  - `settings.json` — keybindings, scan interval, theme, shell preference, font family, font size, line height
- On launch: restores layout and groups. Uses lazy spawning — only terminals in the active tab are spawned immediately. Terminals in background tabs spawn when their tab is first focused. This prevents launching dozens of sessions simultaneously.
- Auto-saves on changes (debounced 2 seconds)

**Error handling:**
- If `state.json` is corrupted or unreadable: reset to defaults (empty state), show a notification. A backup of the last valid state is kept at `state.json.bak`.
- If `presets.json` is missing: regenerate with built-in defaults
- If `settings.json` is missing: use built-in defaults

### Layer 4: Process Scanner

- Background scanner runs every 10 seconds by default (configurable). First scan is deferred until 3 seconds after launch to avoid startup slowdown.
- Only scans processes owned by the current UID
- On Mac: uses `proc_pidinfo` via a native addon for performance (avoids shelling out to `lsof` which is slow on machines with many file descriptors). Falls back to `ps -eo pid,comm,cwd -u $UID` if the native addon is unavailable.
- On Linux: reads `/proc/*/cwd` symlinks for known shell processes owned by the current user
- Filters out non-interactive/daemon shells (ignores processes without a controlling terminal)
- Matches detected processes against known terminal emulators (iTerm2, Terminal.app, GNOME Terminal, Alacritty, Kitty, VS Code integrated terminal)
- Groups detected terminals by CWD and matches to existing project tabs

## Keyboard Shortcuts

### Global

| Shortcut | Action |
|---|---|
| `Cmd+K` | Fuzzy search — find and switch to terminals, projects by name |
| `Cmd+N` | New terminal in current project |
| `Cmd+T` | New project tab |
| `Cmd+W` | Close current terminal |
| `Cmd+1-9` | Switch to project tab by position |
| `Cmd+Shift+]` / `[` | Next / previous project tab |
| `Ctrl+Tab` | Cycle terminals within current project |
| `Cmd+D` | Split terminal horizontally |
| `Cmd+Shift+D` | Split terminal vertically |
| `Cmd+Shift+P` | Command palette — launch presets, run actions, open settings |
| `Cmd+,` | Open settings |

### Terminal Navigation

| Shortcut | Action |
|---|---|
| `Cmd+Alt+Arrow` | Move focus between split panes |
| `Cmd+Shift+Enter` | Maximize/restore current terminal (zen mode) |

All shortcuts are remappable in settings.

**`Cmd+K` vs `Cmd+Shift+P`:** These are two distinct UIs. `Cmd+K` is a quick switcher — fuzzy search to jump to a terminal or project tab by name. `Cmd+Shift+P` is the command palette — access presets, actions (new tab, close all, settings), and the full quick-launch flow.

## Presets System

Presets are named command templates stored in `~/.config/dispatch/presets.json`:

```json
{
  "presets": [
    {
      "name": "Claude Code",
      "command": "claude",
      "color": "#0f3460",
      "icon": "brain"
    },
    {
      "name": "Resume Session",
      "command": "claude --resume",
      "color": "#e94560",
      "icon": "rotate-ccw"
    },
    {
      "name": "Skip Permissions",
      "command": "claude --dangerously-skip-permissions",
      "color": "#f5a623",
      "icon": "zap"
    },
    {
      "name": "Shell",
      "command": "$SHELL",
      "color": "#888",
      "icon": "terminal",
      "env": {}
    }
  ]
}
```

- Ships with sensible defaults (the above four)
- User can add/edit/delete via settings UI or by editing the JSON directly
- Each preset gets a color and icon shown in the sidebar quick-launch buttons
- The `command` field supports shell variable expansion (e.g. `$SHELL`, `$HOME`)
- The optional `env` field is an object of additional environment variables to set for the spawned process (e.g. `{"NODE_ENV": "development"}`)
- Quick-launch bar shows most-used presets as one-click buttons

### Quick Launch Flow (via command palette)

1. `Cmd+Shift+P` opens command palette
2. Type preset name (e.g. "resume") — fuzzy matched via fuse.js
3. If no project selected, shows folder picker
4. Enter — terminal spawns with that preset in that folder

## External Terminal Detection & Adoption

### Detection

- Background scanner runs every 10 seconds (configurable)
- Finds terminal processes by scanning OS-level process info (current UID only)
- Groups by CWD, matches to project tabs
- Detected externals appear in sidebar with "EXTERNAL" badge (dimmed styling)

### Adoption (attach flow)

When clicking an external terminal entry:

1. Check if the external session is inside a tmux session
2. If yes: attach via `tmux attach-session -t <session>` inside a new Dispatch PTY. Terminal status changes to ATTACHING, then RUNNING on success.
3. If no (not in tmux): show the terminal's process info and CWD in the sidebar for reference, but do not attempt to attach. The user can click to open a new Dispatch terminal in the same CWD with a chosen preset (effectively "take over" the project, not the session).
4. Fallback: if tmux isn't installed, external terminals are shown in the sidebar for awareness only (CWD + process info). Clicking opens a new terminal in that CWD.

The "wrap" flow (programmatically sending commands to external terminal emulators) is deferred to a future version due to platform fragility.

### tmux Dependency

- tmux is required for attaching to external terminal sessions, NOT for core functionality
- On first launch, Dispatch checks for tmux and shows a non-blocking notice if missing: "Install tmux to enable attaching to external terminals"
- Without tmux: external terminals are shown for awareness, clicking opens a new terminal in the same CWD
- All other features work without tmux

## IPC Channels

| Channel | Direction | Purpose |
|---|---|---|
| `pty:spawn` | renderer → main | Create new PTY with shell, CWD, command |
| `pty:data` | bidirectional | Stream terminal I/O |
| `pty:resize` | renderer → main | Terminal resize events |
| `pty:exit` | main → renderer | Process exited (includes exit code and signal) |
| `pty:kill` | renderer → main | Close a terminal |
| `scanner:results` | main → renderer | External terminal scan results |
| `scanner:attach` | renderer → main | Attach to external terminal |
| `state:save` | renderer → main | Persist layout/groups to disk |
| `state:load` | main → renderer | Restore layout on launch |

## State Management

- React UI state managed with Zustand
- Terminal instances, active tab, sidebar state, split pane layout
- Ephemeral — rebuilt from session store on launch
- State auto-saves to disk on changes (debounced 2 seconds)

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Electron (latest stable) |
| UI | React 18 + TypeScript |
| State | Zustand |
| Terminal | xterm.js + xterm-addon-fit + xterm-addon-webgl (with canvas fallback) |
| PTY | node-pty |
| Styling | Tailwind CSS |
| Build | electron-builder (Mac DMG + Linux AppImage/deb) |
| External attach | tmux (optional runtime dependency) |
| Fuzzy search | fuse.js |
| IPC | Electron contextBridge + ipcMain/ipcRenderer |

**xterm-addon-webgl note:** WebGL rendering is used by default for performance. If WebGL initialization fails (common on some Linux GPU drivers with Mesa), Dispatch automatically falls back to the canvas renderer.

## Theming

- Ships with a single dark theme (the default)
- Terminal colors (ANSI palette) and app chrome use a shared color config
- Font family, size, and line height are configurable in settings (defaults: system monospace, 13px, 1.2)
- Custom xterm.js color themes are deferred to a future version — v1 uses one well-designed dark theme

## Out of Scope (v1)

- No cloud sync / multi-machine state
- No built-in AI features beyond launching Claude Code
- No plugin/extension system
- No Windows support
- No terminal multiplexing within Dispatch (splits are UI-level, not tmux)
- No custom color themes (single dark theme for v1)
- No programmatic "wrap" flow for non-tmux external terminals
