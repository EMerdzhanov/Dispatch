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
- Folder-based tabs auto-created when opening a terminal in a new directory
- Custom groups created via "+" button (for cross-directory task grouping)
- Tabs show folder name (e.g. `~/Projects/dispatch`) or custom label (e.g. "DevOps Tasks")
- Active tab highlighted with accent color border
- `Cmd+1-9` to switch by position, `Cmd+Shift+]`/`[` to cycle

### Left Sidebar

Two zones stacked vertically:

**Quick Launch (top):** Compact preset buttons. Each shows the preset name with its assigned color. Click a preset to spawn a terminal with that command in the current project's directory.

**Terminal List (bottom):** All terminals in the active project tab. Each entry shows:
- Terminal type (Claude Code / Shell)
- Running command (truncated)
- Status badge: ACTIVE (focused), RUNNING (background), EXTERNAL (detected from another app)
- Active terminal highlighted with accent-color left border

**Status Bar (bottom edge):** Terminal count and external terminal count for the current project.

### Main Terminal Area

- Full xterm.js terminal filling the remaining space
- Header bar showing terminal context (type, CWD) and contextual shortcuts
- Supports split panes: horizontal (`Cmd+D`) and vertical (`Cmd+Shift+D`)
- Splits are UI-level (separate xterm.js instances), not tmux splits
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
- For external terminal adoption: integrates with tmux to attach to existing sessions

### Layer 3: Session Store

- JSON files at `~/.config/dispatch/`:
  - `state.json` — project groups (tabs), terminal entries per group (command, CWD, position), sidebar layout, window geometry
  - `presets.json` — command presets
  - `settings.json` — keybindings, scan interval, theme, shell preference
- On launch: restores layout and groups, spawns fresh terminals with saved commands
- Auto-saves on changes (debounced 2 seconds)

### Layer 4: Process Scanner

- Background scanner runs every 5 seconds (configurable)
- On Mac: uses `ps` + `lsof` to find terminal emulator processes and their CWDs
- On Linux: reads `/proc/*/cwd` symlinks for known shell processes
- Matches detected processes against known terminal emulators (iTerm2, Terminal.app, GNOME Terminal, Alacritty, Kitty, VS Code integrated terminal)
- Groups detected terminals by CWD and matches to existing project tabs

## Keyboard Shortcuts

### Global

| Shortcut | Action |
|---|---|
| `Cmd+K` | Fuzzy search — find terminals, projects, presets, commands |
| `Cmd+N` | New terminal in current project |
| `Cmd+T` | New project tab |
| `Cmd+W` | Close current terminal |
| `Cmd+1-9` | Switch to project tab by position |
| `Cmd+Shift+]` / `[` | Next / previous project tab |
| `Ctrl+Tab` | Cycle terminals within current project |
| `Cmd+D` | Split terminal horizontally |
| `Cmd+Shift+D` | Split terminal vertically |
| `Cmd+Shift+P` | Command palette (presets, settings, actions) |
| `Cmd+,` | Open settings |

### Terminal Navigation

| Shortcut | Action |
|---|---|
| `Cmd+Alt+Arrow` | Move focus between split panes |
| `Cmd+Shift+Enter` | Maximize/restore current terminal (zen mode) |

All shortcuts are remappable in settings.

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
      "icon": "terminal"
    }
  ]
}
```

- Ships with sensible defaults (the above four)
- User can add/edit/delete via settings UI or by editing the JSON directly
- Each preset gets a color and icon shown in the sidebar quick-launch buttons
- Presets can include environment variables and arguments
- Quick-launch bar shows most-used presets as one-click buttons

### Quick Launch Flow

1. `Cmd+Shift+P` opens command palette
2. Type preset name (e.g. "resume") — fuzzy matched via fuse.js
3. If no project selected, shows folder picker
4. Enter — terminal spawns with that preset in that folder

## External Terminal Detection & Adoption

### Detection

- Background scanner runs every 5 seconds
- Finds terminal processes by scanning OS-level process info
- Groups by CWD, matches to project tabs
- Detected externals appear in sidebar with "EXTERNAL" badge (dimmed styling)

### Adoption (attach flow)

When clicking an external terminal entry:

1. Check if the external session is inside a tmux session
2. If yes: attach via `tmux attach-session -t <session>` inside a new Dispatch PTY
3. If no: offer to "wrap" — Dispatch creates a tmux session, sends the external terminal a command to join it, then attaches from Dispatch's side
4. Fallback: if tmux isn't available, show a notification pointing to the external app

Once attached, the terminal moves from "EXTERNAL" to "RUNNING" status.

### tmux Dependency

- tmux is required for external terminal adoption only, NOT for core functionality
- On first launch, Dispatch checks for tmux and shows a non-blocking notice if missing
- All other features work without tmux

## IPC Channels

| Channel | Direction | Purpose |
|---|---|---|
| `pty:spawn` | renderer → main | Create new PTY with shell, CWD, command |
| `pty:data` | bidirectional | Stream terminal I/O |
| `pty:resize` | renderer → main | Terminal resize events |
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
| Terminal | xterm.js + xterm-addon-fit + xterm-addon-webgl |
| PTY | node-pty |
| Styling | Tailwind CSS |
| Build | electron-builder (Mac DMG + Linux AppImage/deb) |
| External attach | tmux (optional runtime dependency) |
| Fuzzy search | fuse.js |
| IPC | Electron contextBridge + ipcMain/ipcRenderer |

## Out of Scope (v1)

- No cloud sync / multi-machine state
- No built-in AI features beyond launching Claude Code
- No plugin/extension system
- No Windows support
- No terminal multiplexing within Dispatch (splits are UI-level, not tmux)
