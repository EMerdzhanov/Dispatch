# Dispatch Power Features — Design Spec

Four features that transform Dispatch from a terminal manager into an agentic IDE command center.

## Feature 1: Multi-Pane View

### Overview

Manual split panes — `Cmd+D` splits the active terminal horizontally, `Cmd+Shift+D` splits vertically. Each pane is an independent terminal with its own PTY and tmux session.

### Behavior

- `Cmd+D` on active pane → splits it horizontally, spawns a new shell in the new half
- `Cmd+Shift+D` → same but vertical split
- `Cmd+Alt+Arrow` → moves focus between panes
- `Cmd+W` → closes the active pane and collapses the split (sibling pane expands to fill)
- `Cmd+Shift+Enter` → zen mode (maximize active pane, hide all others temporarily)
- Draggable dividers between panes to resize (min 15%, max 85%)

### Data Model

Split layout is a recursive binary tree stored per project group:

```typescript
type SplitNode = SplitLeaf | SplitBranch;

interface SplitLeaf {
  type: 'leaf';
  terminalId: string;
}

interface SplitBranch {
  type: 'branch';
  direction: 'horizontal' | 'vertical';
  children: [SplitNode, SplitNode];
  ratio: number; // 0.0–1.0, position of divider
}
```

Each project group in the Zustand store has a `splitLayout: SplitNode | null` field. When `null`, the active terminal renders full-width (single pane). On first split, a `SplitBranch` wraps the current leaf and a new leaf.

### Integration with Sidebar

- The sidebar terminal list shows ALL terminals in the group, regardless of split layout
- Clicking a terminal in the sidebar focuses its pane (scrolls to it if needed)
- The active pane's terminal entry is highlighted in the sidebar
- Closing a terminal via right-click also removes it from the split tree

### Existing Code

`SplitContainer.tsx` and the `SplitNode` type already exist and handle rendering + divider dragging. `splitTerminal()` action exists in the store but only handles the first split. What needs to be built:
- Wire `Cmd+D`/`Cmd+Shift+D` to spawn a new terminal AND update the split tree
- `Cmd+W` needs to collapse the split tree when closing a pane
- Store `splitLayout` per group (currently global)
- Clicking a sidebar entry should focus the correct pane

---

## Feature 2: Activity Monitor

### Overview

A lightweight output parser watches each terminal's data stream and classifies terminal state. Shows colored status dots in the sidebar and sends desktop notifications + sounds on key events.

### Terminal States

| State | Dot Color | Trigger |
|-------|-----------|---------|
| Idle | Gray | Shell prompt visible, no output for 3+ seconds |
| Running | Blue (pulse) | Output flowing actively |
| Success | Green | Pattern match: `✓`, `passed`, `completed`, `Done!`, `All.*passed`, exit code 0 |
| Error | Red | Pattern match: `error`, `Error:`, `failed`, `FAIL`, `✗`, exit code non-zero |
| Waiting | Yellow | Pattern match: `?`, `(y/n)`, `Continue?`, `approve`, permission prompts |

### Architecture

**Main process — `TerminalMonitor` class (`src/main/terminal-monitor.ts`):**
- Receives data chunks from PTY manager (taps into existing `onData` callbacks)
- Maintains a rolling buffer of the last 500 characters per terminal
- Runs regex pattern matching on each data chunk
- Tracks activity timing (last output timestamp for idle detection)
- Emits status changes via IPC channel `monitor:status` to renderer
- Debounces status changes (100ms) to avoid flickering

**Renderer — Zustand store:**
- New field: `terminalStatuses: Record<string, TerminalActivityStatus>`
- Updated by IPC listener in `App.tsx`
- `TerminalEntry` reads status and renders the colored dot

**Notifications:**
- On transition to `success` or `error` → Electron `new Notification({ title, body })` from main process
- Notification body shows: terminal type (Claude Code/Shell) + project folder name
- Sound: bundled `.mp3` files played via `new Audio()` in renderer
  - Success: subtle chime
  - Error: alert tone
- Sounds and notifications togglable in Settings (`notificationsEnabled`, `soundEnabled`)

### Pattern Matching

Patterns are configurable but ship with sensible defaults. Matching runs on the raw text (ANSI codes stripped). The monitor checks the last received chunk against patterns in priority order (error > success > waiting > running > idle).

### Not Included

- No AI/LLM analysis of terminal output
- No semantic understanding of what Claude is doing
- No log persistence of status history

---

## Feature 3: Session Templates

### Overview

Save your current workspace layout as a named template. Restore it with one click to instantly recreate your full development environment.

### Save Flow

1. User sets up workspace: opens folder, spawns terminals, arranges splits
2. `Cmd+Shift+S` or right-click tab → "Save as Template"
3. Dialog asks for template name (pre-filled with folder name)
4. Template captures: folder path, terminal commands, split layout positions
5. Saved to `~/.config/dispatch/templates.json`

### Restore Flow

1. Welcome screen shows saved templates below "Open Folder" button
2. Click a template → opens folder, spawns all terminals, restores split layout
3. Also accessible via Command Palette (`Cmd+Shift+P` → type template name)

### Data Structure

```json
{
  "templates": [
    {
      "name": "MandaPost",
      "cwd": "/Users/osemdynamics/Desktop/MandaPost",
      "terminals": [
        { "command": "claude --dangerously-skip-permissions", "position": "left" },
        { "command": "claude --dangerously-skip-permissions", "position": "right-top" },
        { "command": "$SHELL", "position": "right-bottom" }
      ]
    }
  ]
}
```

**Position encoding:**
- Single pane: `"full"`
- First split: `"left"` / `"right"` (horizontal) or `"top"` / `"bottom"` (vertical)
- Nested: `"left"`, `"right-top"`, `"right-bottom"` (right pane split vertically)
- Deeper nesting follows the same pattern with `-` separators

### Template Management

- Templates listed in Settings panel under a "Templates" section
- Each template shows: name, folder path, terminal count
- Delete button per template
- No edit UI — delete and re-save to modify

### Persistence

- `~/.config/dispatch/templates.json` managed by `SessionStore`
- `SessionStore` gets new methods: `loadTemplates()`, `saveTemplates()`

---

## Feature 4: Auto-Resume

### Overview

On launch, Dispatch checks for tmux sessions from previous runs and offers to restore them.

### Session Naming

Change tmux session names from `dispatch-<uuid>` to `dispatch-<folder-name>-<index>`:
- `dispatch-MandaPost-0`, `dispatch-MandaPost-1`
- Makes sessions human-readable in the resume modal and in `tmux ls`
- Index increments per folder (0, 1, 2...)

### Startup Flow

1. On launch, before showing the welcome screen, scan for existing tmux sessions:
   ```bash
   tmux list-sessions -F "#{session_name}:#{session_activity}:#{pane_current_path}" 2>/dev/null
   ```
2. Filter for sessions starting with `dispatch-`
3. If none found → show normal welcome screen
4. If found → show resume modal

### Resume Modal

A centered overlay (like the command palette) showing:

```
Restore Previous Sessions

Found 5 sessions from your last run:

☑ MandaPost (2 terminals)
   claude --dangerously-skip-permissions
   claude --dangerously-skip-permissions

☑ Helpdesk v2.0 (2 terminals)
   claude
   $SHELL

☑ redpilltube (1 terminal)
   $SHELL

[Restore Selected]  [Start Fresh]
```

- Checkboxes default to all selected
- "Restore Selected" → attaches to selected tmux sessions, creates project tabs
- "Start Fresh" → kills all `dispatch-*` tmux sessions, shows welcome screen

### Restore Process

For each selected session:
1. Extract folder name from session name (`dispatch-MandaPost-0` → `MandaPost`)
2. Get CWD from tmux: `tmux display-message -t <session> -p "#{pane_current_path}"`
3. Create/find project group for that CWD
4. Spawn PTY with `tmux attach-session -t <session>` (not `new-session`)
5. Terminal reconnects with full scrollback and any running process intact

### Cleanup

- `Cmd+W` on a terminal kills the tmux session (already happens via `pty.kill`)
- "Start Fresh" kills all `dispatch-*` sessions before proceeding
- Orphaned sessions (where the inner process exited) show as "(exited)" in the modal — still attachable for scrollback review

### Edge Cases

- tmux not installed → skip resume check entirely
- Session exists but tmux server died → `tmux list-sessions` returns error, treat as no sessions
- CWD no longer exists → show session in modal with "(folder missing)" note, skip on restore

---

## Shared Concerns

### New IPC Channels

| Channel | Direction | Purpose |
|---|---|---|
| `monitor:status` | main → renderer | Terminal activity status update |
| `templates:load` | renderer → main | Load saved templates |
| `templates:save` | renderer → main | Save templates |
| `resume:scan` | renderer → main | Scan for existing tmux sessions |
| `resume:restore` | renderer → main | Attach to selected tmux sessions |
| `resume:cleanup` | renderer → main | Kill old tmux sessions |

### New Settings Fields

```typescript
interface Settings {
  // ... existing fields ...
  notificationsEnabled: boolean;  // default: true
  soundEnabled: boolean;          // default: true
}
```

### New Files

| File | Purpose |
|---|---|
| `src/main/terminal-monitor.ts` | Activity monitoring + pattern matching |
| `src/renderer/components/ResumeModal.tsx` | Startup resume dialog |
| `src/renderer/components/SaveTemplateDialog.tsx` | Save template name dialog |
| `src/assets/success.mp3` | Success notification sound |
| `src/assets/error.mp3` | Error notification sound |

### Modified Files

| File | Changes |
|---|---|
| `src/main/pty-manager.ts` | Readable tmux session names, expose session listing |
| `src/main/ipc.ts` | New IPC handlers for monitor, templates, resume |
| `src/main/session-store.ts` | Template load/save methods |
| `src/main/preload.ts` | Expose new IPC channels |
| `src/renderer/store/index.ts` | Split layout per group, terminal statuses, template state |
| `src/renderer/store/types.ts` | New types for activity status, templates |
| `src/renderer/App.tsx` | Resume modal on startup, monitor listener, template save |
| `src/renderer/components/TerminalEntry.tsx` | Activity status dot |
| `src/renderer/components/TerminalPane.tsx` | Pane focus tracking for splits |
| `src/renderer/components/TerminalArea.tsx` | Full split tree rendering |
| `src/renderer/components/CommandPalette.tsx` | Template items in palette |
| `src/renderer/components/SettingsPanel.tsx` | Notification/sound toggles, template list |
| `src/renderer/styles/dispatch.css` | New classes for resume modal, status dots, template UI |
| `src/renderer/hooks/useShortcuts.ts` | Cmd+Shift+S for save template |

### Out of Scope

- No AI analysis of terminal output
- No template sharing/export
- No auto-tiling (manual splits only)
- No inter-session communication
- No file tree or diff viewer (future features)
