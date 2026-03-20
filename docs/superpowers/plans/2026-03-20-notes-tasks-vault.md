# Notes, Tasks & Vault Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-project Tasks, Notes, and Vault panels to the bottom half of the Dispatch sidebar.

**Architecture:** The sidebar splits vertically — terminals on top, a three-tab panel (Tasks/Notes/Vault) on bottom. A `ProjectDataStore` class in the main process handles per-project JSON persistence. The renderer loads data when the active project changes and auto-saves on edits (debounced). Each panel is its own React component.

**Tech Stack:** Existing stack (Electron, React, TypeScript, Zustand). Node.js `crypto` for SHA-256 hashing. No new dependencies.

---

## File Structure

```
src/
├── shared/
│   └── types.ts                      # Add Task, Note, VaultEntry interfaces
├── main/
│   ├── project-data-store.ts         # NEW: Per-project JSON persistence
│   ├── ipc.ts                        # Add project data IPC handlers
│   └── preload.ts                    # Expose project data channels
├── renderer/
│   ├── store/
│   │   ├── types.ts                  # Add panel state fields + actions
│   │   └── index.ts                  # Implement panel actions
│   ├── components/
│   │   ├── Sidebar.tsx               # Split into top/bottom sections
│   │   ├── ProjectPanel.tsx          # NEW: Tab switcher (Tasks/Notes/Vault)
│   │   ├── TasksPanel.tsx            # NEW: Todo list UI
│   │   ├── NotesPanel.tsx            # NEW: Named notes with list/edit views
│   │   └── VaultPanel.tsx            # NEW: Secret store with copy
│   ├── hooks/
│   │   └── usePty.ts                 # Add useProjectApi() hook
│   └── styles/
│       └── dispatch.css              # Panel classes
├── App.tsx                           # Load project data on tab change
tests/
├── main/
│   └── project-data-store.test.ts    # NEW
```

---

### Task 1: Shared Types + ProjectDataStore

**Files:**
- Modify: `src/shared/types.ts`
- Create: `src/main/project-data-store.ts`
- Create: `tests/main/project-data-store.test.ts`

- [ ] **Step 1: Add types to shared/types.ts**

```typescript
// Add after the existing Template interface:

export interface Task {
  id: string;
  title: string;
  description: string;
  done: boolean;
}

export interface Note {
  id: string;
  title: string;
  body: string;
  updatedAt: number;
}

export interface VaultEntry {
  id: string;
  label: string;
  value: string;
}
```

- [ ] **Step 2: Write failing tests for ProjectDataStore**

```typescript
// tests/main/project-data-store.test.ts
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { ProjectDataStore } from '../../src/main/project-data-store';

describe('ProjectDataStore', () => {
  let tmpDir: string;
  let store: ProjectDataStore;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dispatch-pds-'));
    store = new ProjectDataStore(tmpDir);
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('generates deterministic project dir from CWD', () => {
    const dir1 = store.getProjectDir('/Users/test/project');
    const dir2 = store.getProjectDir('/Users/test/project');
    expect(dir1).toBe(dir2);
  });

  it('generates different dirs for different CWDs', () => {
    const dir1 = store.getProjectDir('/Users/test/project1');
    const dir2 = store.getProjectDir('/Users/test/project2');
    expect(dir1).not.toBe(dir2);
  });

  describe('tasks', () => {
    it('returns empty array when no tasks exist', async () => {
      const tasks = await store.loadTasks('/test/project');
      expect(tasks).toEqual([]);
    });

    it('saves and loads tasks', async () => {
      const tasks = [{ id: '1', title: 'Test', description: '', done: false }];
      await store.saveTasks('/test/project', tasks);
      const loaded = await store.loadTasks('/test/project');
      expect(loaded).toEqual(tasks);
    });
  });

  describe('notes', () => {
    it('returns empty array when no notes exist', async () => {
      const notes = await store.loadNotes('/test/project');
      expect(notes).toEqual([]);
    });

    it('saves and loads notes', async () => {
      const notes = [{ id: '1', title: 'Note', body: 'content', updatedAt: Date.now() }];
      await store.saveNotes('/test/project', notes);
      const loaded = await store.loadNotes('/test/project');
      expect(loaded).toEqual(notes);
    });
  });

  describe('vault', () => {
    it('returns empty array when no vault exists', async () => {
      const entries = await store.loadVault('/test/project');
      expect(entries).toEqual([]);
    });

    it('saves and loads vault entries', async () => {
      const entries = [{ id: '1', label: 'API Key', value: 'sk-123' }];
      await store.saveVault('/test/project', entries);
      const loaded = await store.loadVault('/test/project');
      expect(loaded).toEqual(entries);
    });
  });

  it('recovers from corrupted JSON', async () => {
    const dir = store.getProjectDir('/test/corrupt');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'tasks.json'), '{broken json!!');
    const tasks = await store.loadTasks('/test/corrupt');
    expect(tasks).toEqual([]);
  });
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `npx vitest run tests/main/project-data-store.test.ts`
Expected: FAIL — module not found

- [ ] **Step 4: Implement ProjectDataStore**

```typescript
// src/main/project-data-store.ts
import { createHash } from 'crypto';
import fs from 'fs/promises';
import fsSync from 'fs';
import path from 'path';
import type { Task, Note, VaultEntry } from '../shared/types';

export class ProjectDataStore {
  private baseDir: string;

  constructor(baseDir: string) {
    this.baseDir = baseDir;
  }

  getProjectDir(cwd: string): string {
    // Normalize to POSIX slashes, then SHA-256, first 12 hex chars
    const normalized = cwd.replace(/\\/g, '/');
    const hash = createHash('sha256').update(normalized).digest('hex').slice(0, 12);
    return path.join(this.baseDir, hash);
  }

  private async readJson<T>(cwd: string, filename: string, fallback: T): Promise<T> {
    try {
      const filePath = path.join(this.getProjectDir(cwd), filename);
      const raw = await fs.readFile(filePath, 'utf-8');
      return JSON.parse(raw) as T;
    } catch {
      return fallback;
    }
  }

  private async writeJson(cwd: string, filename: string, data: unknown): Promise<void> {
    const dir = this.getProjectDir(cwd);
    if (!fsSync.existsSync(dir)) {
      await fs.mkdir(dir, { recursive: true });
    }
    await fs.writeFile(path.join(dir, filename), JSON.stringify(data, null, 2), 'utf-8');
  }

  async loadTasks(cwd: string): Promise<Task[]> {
    return this.readJson(cwd, 'tasks.json', []);
  }

  async saveTasks(cwd: string, tasks: Task[]): Promise<void> {
    await this.writeJson(cwd, 'tasks.json', tasks);
  }

  async loadNotes(cwd: string): Promise<Note[]> {
    return this.readJson(cwd, 'notes.json', []);
  }

  async saveNotes(cwd: string, notes: Note[]): Promise<void> {
    await this.writeJson(cwd, 'notes.json', notes);
  }

  async loadVault(cwd: string): Promise<VaultEntry[]> {
    return this.readJson(cwd, 'vault.json', []);
  }

  async saveVault(cwd: string, entries: VaultEntry[]): Promise<void> {
    await this.writeJson(cwd, 'vault.json', entries);
  }
}
```

- [ ] **Step 5: Run tests**

Run: `npx vitest run tests/main/project-data-store.test.ts`
Expected: PASS (all 8 tests)

- [ ] **Step 6: Commit**

```bash
git add src/shared/types.ts src/main/project-data-store.ts tests/main/project-data-store.test.ts
git commit -m "feat: add Task/Note/VaultEntry types and ProjectDataStore"
```

---

### Task 2: IPC + Preload + Store

**Files:**
- Modify: `src/main/ipc.ts`
- Modify: `src/main/preload.ts`
- Modify: `src/renderer/hooks/usePty.ts`
- Modify: `src/renderer/store/types.ts`
- Modify: `src/renderer/store/index.ts`

- [ ] **Step 1: Add IPC handlers**

In `src/main/ipc.ts`, add at the top:
```typescript
import { ProjectDataStore } from './project-data-store';
```

Create the store instance (alongside existing `store` variable, wherever `registerIpc` is called from — or inside `registerIpc`):
```typescript
const projectData = new ProjectDataStore(
  path.join(app.getPath('home'), '.config', 'dispatch', 'projects')
);
```

Note: `app` is imported from Electron in `index.ts`, not in `ipc.ts`. Pass the base path from `index.ts` or compute it inside `registerIpc`. The simplest: instantiate it inside `registerIpc` using `require('os').homedir()`:
```typescript
import os from 'os';
const projectData = new ProjectDataStore(
  path.join(os.homedir(), '.config', 'dispatch', 'projects')
);
```

Add handlers:
```typescript
ipcMain.handle('project:loadTasks', async (_event, cwd: string) => projectData.loadTasks(cwd));
ipcMain.handle('project:saveTasks', async (_event, cwd: string, tasks: unknown) => projectData.saveTasks(cwd, tasks as any));
ipcMain.handle('project:loadNotes', async (_event, cwd: string) => projectData.loadNotes(cwd));
ipcMain.handle('project:saveNotes', async (_event, cwd: string, notes: unknown) => projectData.saveNotes(cwd, notes as any));
ipcMain.handle('project:loadVault', async (_event, cwd: string) => projectData.loadVault(cwd));
ipcMain.handle('project:saveVault', async (_event, cwd: string, entries: unknown) => projectData.saveVault(cwd, entries as any));
```

- [ ] **Step 2: Update preload**

In `src/main/preload.ts`, add to the dispatch object:
```typescript
project: {
  loadTasks: (cwd: string) => ipcRenderer.invoke('project:loadTasks', cwd),
  saveTasks: (cwd: string, tasks: unknown) => ipcRenderer.invoke('project:saveTasks', cwd, tasks),
  loadNotes: (cwd: string) => ipcRenderer.invoke('project:loadNotes', cwd),
  saveNotes: (cwd: string, notes: unknown) => ipcRenderer.invoke('project:saveNotes', cwd, notes),
  loadVault: (cwd: string) => ipcRenderer.invoke('project:loadVault', cwd),
  saveVault: (cwd: string, entries: unknown) => ipcRenderer.invoke('project:saveVault', cwd, entries),
},
```

- [ ] **Step 3: Add useProjectApi hook**

In `src/renderer/hooks/usePty.ts`, add:
```typescript
export function useProjectApi() {
  return (window as any).dispatch.project;
}
```

- [ ] **Step 4: Update store types**

In `src/renderer/store/types.ts`, add imports:
```typescript
import type { Task, Note, VaultEntry } from '../../shared/types';
```

Add to `StoreState`:
```typescript
  projectTasks: Task[];
  projectNotes: Note[];
  projectVault: VaultEntry[];
  activePanel: 'tasks' | 'notes' | 'vault';
  editingNoteId: string | null;  // null = list view, string = editing that note
```

Add to `StoreActions`:
```typescript
  setProjectTasks: (tasks: Task[]) => void;
  setProjectNotes: (notes: Note[]) => void;
  setProjectVault: (entries: VaultEntry[]) => void;
  setActivePanel: (panel: 'tasks' | 'notes' | 'vault') => void;
  setEditingNoteId: (id: string | null) => void;
```

- [ ] **Step 5: Implement store actions**

In `src/renderer/store/index.ts`, add initial state:
```typescript
  projectTasks: [],
  projectNotes: [],
  projectVault: [],
  activePanel: 'tasks' as const,
  editingNoteId: null,
```

Add actions:
```typescript
  setProjectTasks: (tasks) => set({ projectTasks: tasks }),
  setProjectNotes: (notes) => set({ projectNotes: notes }),
  setProjectVault: (entries) => set({ projectVault: entries }),
  setActivePanel: (panel) => set({ activePanel: panel }),
  setEditingNoteId: (id) => set({ editingNoteId: id }),
```

- [ ] **Step 6: Build and test**

Run: `npm run build && npx vitest run`
Expected: Clean build, all tests pass

- [ ] **Step 7: Commit**

```bash
git add src/main/ipc.ts src/main/preload.ts src/renderer/hooks/usePty.ts src/renderer/store/types.ts src/renderer/store/index.ts
git commit -m "feat: add project data IPC handlers, preload API, and store state"
```

---

### Task 3: CSS Classes for Panels

**Files:**
- Modify: `src/renderer/styles/dispatch.css`

- [ ] **Step 1: Add panel CSS classes**

Add before the `@keyframes` section at the end of `dispatch.css`:

```css
/* ============================================
   PROJECT PANEL (Tasks / Notes / Vault)
   ============================================ */
.d-project-panel {
  display: flex;
  flex-direction: column;
  border-top: 1px solid var(--border-default);
  min-height: 0;
  flex: 1;
}

.d-panel-tabs {
  display: flex;
  flex-shrink: 0;
  border-bottom: 1px solid var(--border-default);
}

.d-panel-tab {
  flex: 1;
  padding: 5px 0;
  font-size: 10px;
  text-align: center;
  color: var(--text-dim);
  transition: color 0.15s, background 0.15s;
  border-bottom: 2px solid transparent;
}

.d-panel-tab:hover { color: var(--text-muted); background: var(--bg-tertiary); }

.d-panel-tab--active {
  color: var(--accent-primary);
  border-bottom-color: var(--accent-primary);
}

.d-panel-content {
  flex: 1;
  overflow-y: auto;
  padding: var(--space-2);
  min-height: 0;
}

/* Tasks */
.d-task-input {
  width: 100%;
  padding: 5px 8px;
  border-radius: var(--radius-sm);
  font-size: var(--font-size-sm);
  background: var(--bg-primary);
  color: var(--text-primary);
  border: 1px solid var(--border-subtle);
  margin-bottom: var(--space-2);
}
.d-task-input::placeholder { color: var(--text-dim); }
.d-task-input:focus { border-color: var(--border-default); }

.d-task-item {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  padding: 4px 2px;
  border-radius: var(--radius-sm);
  position: relative;
}
.d-task-item:hover { background: var(--bg-tertiary); }

.d-task-item__checkbox {
  margin-top: 2px;
  flex-shrink: 0;
  cursor: pointer;
}

.d-task-item__title {
  font-size: var(--font-size-sm);
  color: var(--text-secondary);
  cursor: pointer;
  flex: 1;
  word-break: break-word;
}

.d-task-item--done .d-task-item__title {
  text-decoration: line-through;
  color: var(--text-dim);
}

.d-task-item__delete {
  font-size: 10px;
  color: var(--text-dim);
  opacity: 0;
  transition: opacity 0.1s;
  flex-shrink: 0;
  padding: 0 2px;
}
.d-task-item:hover .d-task-item__delete { opacity: 1; }
.d-task-item__delete:hover { color: var(--accent-primary); }

.d-task-item__desc {
  font-size: var(--font-size-xs);
  color: var(--text-dim);
  padding: 4px 0 4px 20px;
  width: 100%;
  min-height: 40px;
  background: var(--bg-primary);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  resize: vertical;
}

/* Notes */
.d-note-item {
  padding: 6px var(--space-2);
  border-radius: var(--radius-sm);
  cursor: pointer;
  margin-bottom: 2px;
  transition: background 0.1s;
}
.d-note-item:hover { background: var(--bg-tertiary); }

.d-note-item__title {
  font-size: var(--font-size-sm);
  color: var(--text-secondary);
}

.d-note-item__date {
  font-size: var(--font-size-xs);
  color: var(--text-dim);
  margin-top: 1px;
}

.d-note-edit__header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin-bottom: var(--space-2);
}

.d-note-edit__back {
  font-size: 14px;
  color: var(--text-muted);
  flex-shrink: 0;
}
.d-note-edit__back:hover { color: var(--text-primary); }

.d-note-edit__title {
  flex: 1;
  font-size: var(--font-size-sm);
  font-weight: 600;
  padding: 2px 6px;
  background: transparent;
  color: var(--text-primary);
  border: 1px solid transparent;
  border-radius: var(--radius-sm);
}
.d-note-edit__title:focus { border-color: var(--border-default); background: var(--bg-primary); }

.d-note-edit__body {
  width: 100%;
  flex: 1;
  min-height: 80px;
  font-size: var(--font-size-sm);
  color: var(--text-secondary);
  background: var(--bg-primary);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: var(--space-2);
  resize: none;
}
.d-note-edit__body:focus { border-color: var(--border-default); }

/* Vault */
.d-vault-item {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: 5px var(--space-2);
  border-radius: var(--radius-sm);
  margin-bottom: 2px;
}
.d-vault-item:hover { background: var(--bg-tertiary); }

.d-vault-item__label {
  flex: 1;
  font-size: var(--font-size-sm);
  color: var(--text-secondary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.d-vault-item__preview {
  font-size: var(--font-size-xs);
  color: var(--text-dim);
  display: none;
}
.d-vault-item:hover .d-vault-item__preview { display: inline; }

.d-vault-item__copy {
  font-size: 10px;
  color: var(--text-muted);
  flex-shrink: 0;
  padding: 2px 6px;
  border-radius: var(--radius-sm);
  transition: background 0.1s;
}
.d-vault-item__copy:hover { background: var(--bg-elevated); }
.d-vault-item__copy--copied { color: var(--accent-green); }

.d-vault-form {
  padding: var(--space-2);
  background: var(--bg-primary);
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-subtle);
  margin-bottom: var(--space-2);
}

.d-vault-form__input {
  width: 100%;
  padding: 4px 8px;
  margin-bottom: var(--space-1);
  font-size: var(--font-size-sm);
  background: var(--bg-tertiary);
  color: var(--text-primary);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-sm);
}
.d-vault-form__input::placeholder { color: var(--text-dim); }

/* Shared panel add button */
.d-panel-add {
  width: 100%;
  padding: 4px;
  font-size: var(--font-size-xs);
  color: var(--text-dim);
  border: 1px dashed var(--border-default);
  border-radius: var(--radius-sm);
  margin-bottom: var(--space-2);
  transition: border-color 0.15s;
}
.d-panel-add:hover { border-color: var(--text-dim); }
```

- [ ] **Step 2: Commit**

```bash
git add src/renderer/styles/dispatch.css
git commit -m "feat: add CSS classes for Tasks, Notes, and Vault panels"
```

---

### Task 4: Sidebar Split + ProjectPanel + TasksPanel

**Files:**
- Modify: `src/renderer/components/Sidebar.tsx`
- Create: `src/renderer/components/ProjectPanel.tsx`
- Create: `src/renderer/components/TasksPanel.tsx`

- [ ] **Step 1: Create TasksPanel**

```typescript
// src/renderer/components/TasksPanel.tsx
import React, { useState } from 'react';
import { useStore } from '../store';
import { useProjectApi } from '../hooks/usePty';
import type { Task } from '../../shared/types';

export function TasksPanel() {
  const tasks = useStore((s) => s.projectTasks);
  const setTasks = useStore((s) => s.setProjectTasks);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const [input, setInput] = useState('');
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const projectApi = useProjectApi();

  const cwd = groups.find((g) => g.id === activeGroupId)?.cwd;

  const save = (updated: Task[]) => {
    setTasks(updated);
    if (cwd) {
      // Debounced save handled by caller or we can do simple timeout
      clearTimeout((save as any)._timer);
      (save as any)._timer = setTimeout(() => {
        projectApi?.saveTasks(cwd, updated);
      }, 500);
    }
  };

  const addTask = () => {
    if (!input.trim()) return;
    const task: Task = { id: crypto.randomUUID(), title: input.trim(), description: '', done: false };
    save([task, ...tasks]);
    setInput('');
  };

  const toggleDone = (id: string) => {
    save(tasks.map((t) => t.id === id ? { ...t, done: !t.done } : t));
  };

  const deleteTask = (id: string) => {
    save(tasks.filter((t) => t.id !== id));
    if (expandedId === id) setExpandedId(null);
  };

  const updateDesc = (id: string, description: string) => {
    save(tasks.map((t) => t.id === id ? { ...t, description } : t));
  };

  // Sort: undone first, then done
  const sorted = [...tasks].sort((a, b) => Number(a.done) - Number(b.done));

  return (
    <div className="d-panel-content">
      <input
        className="d-task-input"
        placeholder="Add task..."
        value={input}
        onChange={(e) => setInput(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter') addTask(); }}
      />
      {sorted.map((task) => (
        <div key={task.id}>
          <div className={`d-task-item${task.done ? ' d-task-item--done' : ''}`}>
            <input
              type="checkbox"
              className="d-task-item__checkbox"
              checked={task.done}
              onChange={() => toggleDone(task.id)}
            />
            <span
              className="d-task-item__title"
              onClick={() => setExpandedId(expandedId === task.id ? null : task.id)}
            >
              {task.title}
            </span>
            <button className="d-task-item__delete" onClick={() => deleteTask(task.id)}>✕</button>
          </div>
          {expandedId === task.id && (
            <textarea
              className="d-task-item__desc"
              placeholder="Add description..."
              value={task.description}
              onChange={(e) => updateDesc(task.id, e.target.value)}
            />
          )}
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Create ProjectPanel (tab switcher)**

```typescript
// src/renderer/components/ProjectPanel.tsx
import React from 'react';
import { useStore } from '../store';
import { TasksPanel } from './TasksPanel';
import { NotesPanel } from './NotesPanel';
import { VaultPanel } from './VaultPanel';

export function ProjectPanel() {
  const activePanel = useStore((s) => s.activePanel);
  const setActivePanel = useStore((s) => s.setActivePanel);

  return (
    <div className="d-project-panel">
      <div className="d-panel-tabs">
        <button
          className={`d-panel-tab${activePanel === 'tasks' ? ' d-panel-tab--active' : ''}`}
          onClick={() => setActivePanel('tasks')}
        >
          ☑ Tasks
        </button>
        <button
          className={`d-panel-tab${activePanel === 'notes' ? ' d-panel-tab--active' : ''}`}
          onClick={() => setActivePanel('notes')}
        >
          📝 Notes
        </button>
        <button
          className={`d-panel-tab${activePanel === 'vault' ? ' d-panel-tab--active' : ''}`}
          onClick={() => setActivePanel('vault')}
        >
          🔑 Vault
        </button>
      </div>
      {activePanel === 'tasks' && <TasksPanel />}
      {activePanel === 'notes' && <NotesPanel />}
      {activePanel === 'vault' && <VaultPanel />}
    </div>
  );
}
```

Note: `NotesPanel` and `VaultPanel` don't exist yet — create placeholder files so the build passes:

```typescript
// src/renderer/components/NotesPanel.tsx
import React from 'react';
export function NotesPanel() {
  return <div className="d-panel-content" style={{ color: 'var(--text-dim)' }}>Notes coming soon</div>;
}
```

```typescript
// src/renderer/components/VaultPanel.tsx
import React from 'react';
export function VaultPanel() {
  return <div className="d-panel-content" style={{ color: 'var(--text-dim)' }}>Vault coming soon</div>;
}
```

- [ ] **Step 3: Update Sidebar to split vertically**

```typescript
// src/renderer/components/Sidebar.tsx
import React from 'react';
import { QuickLaunch } from './QuickLaunch';
import { TerminalList } from './TerminalList';
import { StatusBar } from './StatusBar';
import { ProjectPanel } from './ProjectPanel';

interface SidebarProps {
  onSpawn: (command: string, env?: Record<string, string>) => void;
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

export function Sidebar({ onSpawn, onSpawnInCwd }: SidebarProps) {
  return (
    <div className="d-sidebar">
      {/* Top section: terminals (~60%) */}
      <div style={{ display: 'flex', flexDirection: 'column', flex: '0 0 60%', minHeight: 0, overflow: 'hidden' }}>
        <QuickLaunch onSpawn={onSpawn} />
        <TerminalList onSpawnInCwd={onSpawnInCwd} />
        <StatusBar />
      </div>
      {/* Bottom section: panels (~40%) */}
      <ProjectPanel />
    </div>
  );
}
```

- [ ] **Step 4: Load project data on tab change in App.tsx**

In `src/renderer/App.tsx`, add a useEffect that loads project data when `activeGroupId` changes:

```typescript
// Add after other useEffects
useEffect(() => {
  const state = useStore.getState();
  const group = state.groups.find((g) => g.id === activeGroupId);
  if (!group?.cwd) return;
  const cwd = group.cwd;

  // Load all three panel data for this project
  (window as any).dispatch?.project?.loadTasks(cwd).then((tasks: any) => {
    useStore.getState().setProjectTasks(tasks || []);
  });
  (window as any).dispatch?.project?.loadNotes(cwd).then((notes: any) => {
    useStore.getState().setProjectNotes(notes || []);
  });
  (window as any).dispatch?.project?.loadVault(cwd).then((entries: any) => {
    useStore.getState().setProjectVault(entries || []);
  });
}, [activeGroupId]);
```

- [ ] **Step 5: Build and verify**

Run: `npm run build && npx vitest run`
Expected: Clean build, all tests pass. Tasks panel functional, Notes/Vault show placeholders.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add sidebar split with Tasks panel and project data loading"
```

---

### Task 5: Notes Panel

**Files:**
- Modify: `src/renderer/components/NotesPanel.tsx`

- [ ] **Step 1: Implement NotesPanel with list and edit views**

```typescript
// src/renderer/components/NotesPanel.tsx
import React, { useState } from 'react';
import { useStore } from '../store';
import { useProjectApi } from '../hooks/usePty';
import type { Note } from '../../shared/types';

export function NotesPanel() {
  const notes = useStore((s) => s.projectNotes);
  const setNotes = useStore((s) => s.setProjectNotes);
  const editingNoteId = useStore((s) => s.editingNoteId);
  const setEditingNoteId = useStore((s) => s.setEditingNoteId);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const projectApi = useProjectApi();
  const [contextId, setContextId] = useState<string | null>(null);

  const cwd = groups.find((g) => g.id === activeGroupId)?.cwd;

  const save = (updated: Note[]) => {
    setNotes(updated);
    if (cwd) {
      clearTimeout((save as any)._timer);
      (save as any)._timer = setTimeout(() => {
        projectApi?.saveNotes(cwd, updated);
      }, 500);
    }
  };

  const addNote = () => {
    const note: Note = {
      id: crypto.randomUUID(),
      title: 'Untitled Note',
      body: '',
      updatedAt: Date.now(),
    };
    save([note, ...notes]);
    setEditingNoteId(note.id);
  };

  const updateNote = (id: string, updates: Partial<Note>) => {
    save(notes.map((n) => n.id === id ? { ...n, ...updates, updatedAt: Date.now() } : n));
  };

  const deleteNote = (id: string) => {
    save(notes.filter((n) => n.id !== id));
    setContextId(null);
    if (editingNoteId === id) setEditingNoteId(null);
  };

  // Sort by most recently edited
  const sorted = [...notes].sort((a, b) => b.updatedAt - a.updatedAt);

  // Edit view
  const editingNote = editingNoteId ? notes.find((n) => n.id === editingNoteId) : null;
  if (editingNote) {
    return (
      <div className="d-panel-content" style={{ display: 'flex', flexDirection: 'column' }}>
        <div className="d-note-edit__header">
          <button className="d-note-edit__back" onClick={() => setEditingNoteId(null)}>←</button>
          <input
            className="d-note-edit__title"
            value={editingNote.title}
            onChange={(e) => updateNote(editingNote.id, { title: e.target.value })}
          />
        </div>
        <textarea
          className="d-note-edit__body"
          style={{ flex: 1 }}
          value={editingNote.body}
          onChange={(e) => updateNote(editingNote.id, { body: e.target.value })}
          placeholder="Write your note..."
          autoFocus
        />
      </div>
    );
  }

  // List view
  return (
    <div className="d-panel-content">
      <button className="d-panel-add" onClick={addNote}>+ Add Note</button>
      {sorted.map((note) => (
        <div key={note.id} style={{ position: 'relative' }}>
          <div
            className="d-note-item"
            onClick={() => setEditingNoteId(note.id)}
            onContextMenu={(e) => { e.preventDefault(); setContextId(note.id); }}
          >
            <div className="d-note-item__title">{note.title}</div>
            <div className="d-note-item__date">
              {new Date(note.updatedAt).toLocaleDateString()}
            </div>
          </div>
          {contextId === note.id && (
            <>
              <div className="d-context-overlay" onClick={() => setContextId(null)} />
              <div className="d-context-menu" style={{ position: 'fixed', zIndex: 200 }}>
                <button className="d-context-menu__item d-context-menu__item--danger" onClick={() => deleteNote(note.id)}>
                  Delete Note
                </button>
              </div>
            </>
          )}
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Build and verify**

Run: `npm run build`
Expected: Clean build. Notes panel shows list view, clicking + creates a note, clicking opens edit view.

- [ ] **Step 3: Commit**

```bash
git add src/renderer/components/NotesPanel.tsx
git commit -m "feat: add Notes panel with list and edit views"
```

---

### Task 6: Vault Panel

**Files:**
- Modify: `src/renderer/components/VaultPanel.tsx`

- [ ] **Step 1: Implement VaultPanel**

```typescript
// src/renderer/components/VaultPanel.tsx
import React, { useState } from 'react';
import { useStore } from '../store';
import { useProjectApi } from '../hooks/usePty';
import type { VaultEntry } from '../../shared/types';

export function VaultPanel() {
  const vault = useStore((s) => s.projectVault);
  const setVault = useStore((s) => s.setProjectVault);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const projectApi = useProjectApi();
  const [showForm, setShowForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [formLabel, setFormLabel] = useState('');
  const [formValue, setFormValue] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [contextId, setContextId] = useState<string | null>(null);

  const cwd = groups.find((g) => g.id === activeGroupId)?.cwd;

  const save = (updated: VaultEntry[]) => {
    setVault(updated);
    if (cwd) {
      clearTimeout((save as any)._timer);
      (save as any)._timer = setTimeout(() => {
        projectApi?.saveVault(cwd, updated);
      }, 500);
    }
  };

  const handleSave = () => {
    if (!formLabel.trim() || !formValue.trim()) return;
    if (editId) {
      save(vault.map((e) => e.id === editId ? { ...e, label: formLabel.trim(), value: formValue.trim() } : e));
    } else {
      save([...vault, { id: crypto.randomUUID(), label: formLabel.trim(), value: formValue.trim() }]);
    }
    setShowForm(false);
    setEditId(null);
    setFormLabel('');
    setFormValue('');
  };

  const startEdit = (entry: VaultEntry) => {
    setEditId(entry.id);
    setFormLabel(entry.label);
    setFormValue(entry.value);
    setShowForm(true);
    setContextId(null);
  };

  const deleteEntry = (id: string) => {
    save(vault.filter((e) => e.id !== id));
    setContextId(null);
  };

  const copyToClipboard = async (entry: VaultEntry) => {
    await navigator.clipboard.writeText(entry.value);
    setCopiedId(entry.id);
    setTimeout(() => setCopiedId(null), 1500);
  };

  const maskValue = (val: string): string => {
    if (val.length <= 6) return '••••';
    return val.slice(0, 6) + '••••';
  };

  return (
    <div className="d-panel-content">
      {showForm ? (
        <div className="d-vault-form">
          <input
            className="d-vault-form__input"
            placeholder="Label (e.g. API Key)"
            value={formLabel}
            onChange={(e) => setFormLabel(e.target.value)}
            autoFocus
          />
          <input
            className="d-vault-form__input"
            placeholder="Secret value"
            value={formValue}
            onChange={(e) => setFormValue(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') handleSave(); if (e.key === 'Escape') { setShowForm(false); setEditId(null); } }}
          />
          <div style={{ display: 'flex', gap: 4, marginTop: 4 }}>
            <button className="d-welcome__button" style={{ flex: 1, padding: '4px 0', fontSize: 10 }} onClick={handleSave}>Save</button>
            <button className="d-context-menu__item" style={{ flex: 1, textAlign: 'center', fontSize: 10, padding: '4px 0', borderRadius: 'var(--radius-sm)' }} onClick={() => { setShowForm(false); setEditId(null); }}>Cancel</button>
          </div>
        </div>
      ) : (
        <button className="d-panel-add" onClick={() => { setShowForm(true); setEditId(null); setFormLabel(''); setFormValue(''); }}>
          + Add Secret
        </button>
      )}

      {vault.map((entry) => (
        <div key={entry.id} style={{ position: 'relative' }}>
          <div
            className="d-vault-item"
            onContextMenu={(e) => { e.preventDefault(); setContextId(entry.id); }}
          >
            <span className="d-vault-item__label">{entry.label}</span>
            <span className="d-vault-item__preview">{maskValue(entry.value)}</span>
            <button
              className={`d-vault-item__copy${copiedId === entry.id ? ' d-vault-item__copy--copied' : ''}`}
              onClick={() => copyToClipboard(entry)}
            >
              {copiedId === entry.id ? '✓' : 'Copy'}
            </button>
          </div>
          {contextId === entry.id && (
            <>
              <div className="d-context-overlay" onClick={() => setContextId(null)} />
              <div className="d-context-menu" style={{ position: 'fixed', zIndex: 200 }}>
                <button className="d-context-menu__item" onClick={() => startEdit(entry)}>Edit</button>
                <button className="d-context-menu__item d-context-menu__item--danger" onClick={() => deleteEntry(entry.id)}>Delete</button>
              </div>
            </>
          )}
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Build and verify**

Run: `npm run build`
Expected: Clean build. Vault panel shows add form, entries with Copy button.

- [ ] **Step 3: Commit**

```bash
git add src/renderer/components/VaultPanel.tsx
git commit -m "feat: add Vault panel with secrets storage and copy-to-clipboard"
```

---

### Task 7: Integration Testing

**Files:** None (manual verification)

- [ ] **Step 1: Full build + test suite**

```bash
npm run build && npx vitest run
```

Expected: Clean build, all tests pass.

- [ ] **Step 2: Test Tasks**

1. Open a folder → sidebar bottom shows Tasks tab
2. Type "Fix auth bug" + Enter → task appears
3. Click title → description textarea expands
4. Type a description → auto-saves
5. Click checkbox → task gets strikethrough, moves to bottom
6. Hover → ✕ appears, click to delete

- [ ] **Step 3: Test Notes**

1. Switch to Notes tab
2. Click "+ Add Note" → opens edit view with "Untitled Note"
3. Type a title and body → auto-saves
4. Click ← → back to list, note appears with title
5. Right-click → Delete Note

- [ ] **Step 4: Test Vault**

1. Switch to Vault tab
2. Click "+ Add Secret" → form appears
3. Type label "API Key" and value "sk-abc123" → Save
4. Entry appears with label and Copy button
5. Hover → shows masked preview `sk-abc1••••`
6. Click Copy → shows ✓, value in clipboard
7. Right-click → Edit or Delete

- [ ] **Step 5: Test project switching**

1. Open a second project folder
2. Add tasks/notes/vault in both
3. Switch tabs → each project has its own data
4. Close and reopen Dispatch → data persists

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore: integration testing complete for Notes, Tasks, and Vault"
```
