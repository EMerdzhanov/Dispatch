# Notes, Tasks & Vault — Design Spec

Per-project productivity panels in the Dispatch sidebar. Tasks for tracking work, Notes for reference, Vault for secrets.

## Sidebar Layout

The sidebar splits vertically into two fixed sections:

- **Top (~60%):** Quick Launch + Terminal List (unchanged)
- **Bottom (~40%):** Three-tab panel: ☑ Tasks | 📝 Notes | 🔑 Vault

The divider between top and bottom is fixed (not draggable). The bottom panel has a small tab bar; the active tab's content fills the remaining space. Both sections are always visible — the user can select a terminal on top and grab a secret from the Vault below to paste into the terminal.

## Data Storage

Each project gets a folder keyed by a deterministic hash of its CWD path:

```
~/.config/dispatch/projects/
├── <hash>/
│   ├── tasks.json
│   ├── notes.json
│   └── vault.json
```

The hash is computed as: `SHA-256(absolute CWD path)`, hex-encoded, first 12 characters. Path is normalized to POSIX forward slashes before hashing for cross-platform consistency. Same folder always maps to same project data.

**Error handling:**
- Project directories are auto-created on first write (recursive `mkdir`)
- Corrupted JSON files fall back to empty arrays (`[]`)
- No file locking — single app instance assumed
- Force-save on app exit (flush any pending debounce timers)

**Lifecycle:** `ProjectDataStore` is a singleton created once in the main process alongside `SessionStore`. Data is loaded when the active project tab changes (CWD change) and cached in the renderer store. Switching tabs triggers a fresh load for the new CWD.

### tasks.json

```json
[
  { "id": "uuid", "title": "Fix auth bug", "description": "The login flow fails on...", "done": false },
  { "id": "uuid", "title": "Add tests", "description": "", "done": true }
]
```

### notes.json

```json
[
  { "id": "uuid", "title": "API Endpoints", "body": "POST /auth/login\nGET /users/:id\n...", "updatedAt": 1711000000000 },
  { "id": "uuid", "title": "Meeting notes", "body": "Discussed the migration timeline...", "updatedAt": 1711000001000 }
]
```

### vault.json

```json
[
  { "id": "uuid", "label": "OpenAI API Key", "value": "sk-abc123..." },
  { "id": "uuid", "label": "DB Password", "value": "prod-secret-pw" }
]
```

**Not encrypted.** Plain JSON on disk. User accepted this trade-off for simplicity. No import/export.

### ProjectDataStore

A `ProjectDataStore` class in the main process handles all read/write for project-scoped data. It takes a CWD, computes the hash, and manages the project folder.

```typescript
class ProjectDataStore {
  constructor(private baseDir: string) {} // ~/.config/dispatch/projects

  private projectDir(cwd: string): string // computes hash, returns path

  async loadTasks(cwd: string): Promise<Task[]>
  async saveTasks(cwd: string, tasks: Task[]): Promise<void>

  async loadNotes(cwd: string): Promise<Note[]>
  async saveNotes(cwd: string, notes: Note[]): Promise<void>

  async loadVault(cwd: string): Promise<VaultEntry[]>
  async saveVault(cwd: string, entries: VaultEntry[]): Promise<void>
}
```

## Panel Behavior

- **Tab state persists** when switching between Tasks/Notes/Vault — if you're editing a note and switch to Vault, switching back returns to the same note in edit mode
- **Data reloads on CWD change** — when the user clicks a different project tab, all three panels reload data for the new project
- **No delete confirmations** for Tasks, Notes, or Vault entries — these are lightweight tools, not critical data stores
- **Debounce** resets on each keystroke. On app exit, pending saves are flushed immediately via `app.on('before-quit')`

## Tasks Panel

A compact todo list.

### UI

- Input at top: placeholder "Add task...", press Enter to add
- Scrollable task list below, newest first
- Each task: checkbox | title text | ✕ delete (on hover)
- Click title to expand/collapse description textarea
- Completed tasks: strikethrough, moved to bottom of list

### Interactions

- Enter in input → creates task (title only, no description, unchecked)
- Click checkbox → toggles done, reorders (done items to bottom)
- Click title → expand to show/edit description textarea
- Click ✕ → delete task (no confirmation)
- All changes auto-save (debounced 500ms)

### Data Types

```typescript
interface Task {
  id: string;
  title: string;
  description: string;
  done: boolean;
}
```

## Notes Panel

A mini notebook with named notes.

### UI — List View

- "+ Add Note" button at top
- Scrollable list of note titles, sorted by most recently edited
- Right-click note → "Delete Note" context menu

### UI — Edit View

- Back arrow (←) + editable title
- Plain text textarea filling remaining space
- Auto-saves on edit (debounced 500ms)

### Interactions

- Click + → creates "Untitled Note", opens it immediately
- Click note title → opens edit view
- Click ← → back to list view
- Edit title or body → auto-saves
- Right-click → Delete Note

### Data Types

```typescript
interface Note {
  id: string;
  title: string;
  body: string;
  updatedAt: number; // timestamp for sort order
}
```

## Vault Panel

A key-value secret store with one-click copy.

### UI

- "+ Add Secret" button at top
- Scrollable list of entries: label on left, "Copy" button on right
- Secret values never shown — just the label
- Hover shows masked preview: first 6 chars + `••••` (if value < 6 chars, show all chars masked as `••••`)
- Click Copy → copies value to clipboard, button briefly shows "✓ Copied"

### Add/Edit Flow

- Click + → inline form: label input + value input + Save button
- Right-click entry → "Edit" | "Delete" (no confirmation, same as Tasks)
- Edit form shows the full unmasked value in the input field
- Edit → inline form pre-filled with current values

### Data Types

```typescript
interface VaultEntry {
  id: string;
  label: string;
  value: string;
}
```

## IPC Channels

| Channel | Direction | Purpose |
|---|---|---|
| `project:loadTasks` | renderer → main | Load tasks for a CWD |
| `project:saveTasks` | renderer → main | Save tasks for a CWD |
| `project:loadNotes` | renderer → main | Load notes for a CWD |
| `project:saveNotes` | renderer → main | Save notes for a CWD |
| `project:loadVault` | renderer → main | Load vault for a CWD |
| `project:saveVault` | renderer → main | Save vault for a CWD |

## New Files

| File | Purpose |
|---|---|
| `src/main/project-data-store.ts` | Per-project data persistence (tasks, notes, vault) |
| `src/renderer/components/ProjectPanel.tsx` | Bottom sidebar container with tab switcher |
| `src/renderer/components/TasksPanel.tsx` | Tasks UI |
| `src/renderer/components/NotesPanel.tsx` | Notes UI (list + edit views) |
| `src/renderer/components/VaultPanel.tsx` | Vault UI |

## Modified Files

| File | Changes |
|---|---|
| `src/shared/types.ts` | Task, Note, VaultEntry interfaces |
| `src/main/ipc.ts` | Project data IPC handlers |
| `src/main/preload.ts` | Expose project data channels |
| `src/renderer/store/types.ts` | Per-project panel state (tasks, notes, vault, activePanel) |
| `src/renderer/store/index.ts` | Panel state + actions |
| `src/renderer/components/Sidebar.tsx` | Split into top/bottom sections |
| `src/renderer/styles/dispatch.css` | Panel tab bar, task, note, vault classes |
| `src/renderer/hooks/usePty.ts` | useProjectApi() hook |

## Out of Scope

- No encryption for vault
- No import/export
- No markdown rendering in notes
- No drag-and-drop task reordering
- No due dates, priorities, assignees, or tags on tasks
- No clipboard auto-clear for vault
