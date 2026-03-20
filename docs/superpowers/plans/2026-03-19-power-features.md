# Power Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add working split panes, terminal activity monitoring with notifications, session templates, and auto-resume to Dispatch.

**Architecture:** Four features implemented sequentially. Split panes wire the existing SplitContainer to real terminal spawning. Activity monitor taps PTY data in the main process and pushes status via IPC. Templates serialize the split tree to JSON. Auto-resume scans tmux sessions on startup and presents a restore modal.

**Tech Stack:** Existing stack (Electron, React, TypeScript, xterm.js, node-pty, tmux, Zustand). New: Electron Notification API, bundled audio files.

---

## File Structure

```
src/
├── shared/
│   └── types.ts                    # Add splitLayout to ProjectGroup, new Settings fields, TemplateLeaf type
├── main/
│   ├── pty-manager.ts              # Human-readable tmux session names, listSessions()
│   ├── terminal-monitor.ts         # NEW: Activity monitor (pattern matching + idle timers)
│   ├── ipc.ts                      # New handlers: monitor, templates, resume
│   ├── session-store.ts            # loadTemplates/saveTemplates, settings merge-on-load
│   └── preload.ts                  # Expose new IPC channels
├── renderer/
│   ├── store/
│   │   ├── types.ts                # TerminalActivityStatus, TemplateData, per-group splitLayout
│   │   └── index.ts                # New actions: split wiring, activity statuses, templates
│   ├── components/
│   │   ├── TerminalArea.tsx         # Render split tree from active group
│   │   ├── TerminalEntry.tsx        # Activity status dot
│   │   ├── ResumeModal.tsx          # NEW: Startup session restore dialog
│   │   ├── SaveTemplateDialog.tsx   # NEW: Save template name input
│   │   ├── CommandPalette.tsx       # Add template items
│   │   ├── SettingsPanel.tsx        # Notification toggles, template list
│   │   └── App.tsx                  # Resume flow, monitor listener, template save
│   ├── hooks/
│   │   └── useShortcuts.ts         # Cmd+Shift+S for save template
│   └── styles/
│       └── dispatch.css             # New classes for status dots, resume modal, template UI
├── assets/
│   ├── success.mp3                  # NEW: Success notification sound
│   └── error.mp3                    # NEW: Error notification sound
tests/
├── main/
│   ├── terminal-monitor.test.ts     # NEW
│   └── session-store.test.ts        # Add template tests
```

---

### Task 1: Shared Types + Store Updates

**Files:**
- Modify: `src/shared/types.ts`
- Modify: `src/renderer/store/types.ts`
- Modify: `src/renderer/store/index.ts`

- [ ] **Step 1: Update shared types**

Add to `src/shared/types.ts`:

```typescript
// Add to Settings interface:
  notificationsEnabled: boolean;
  soundEnabled: boolean;

// Update DEFAULT_SETTINGS:
  notificationsEnabled: true,
  soundEnabled: true,

// Add splitLayout to ProjectGroup:
interface ProjectGroup {
  // ... existing fields ...
  splitLayout?: SplitNode | null;
}

// Add template types:
export interface TemplateLeaf {
  type: 'leaf';
  command: string;
}

export interface TemplateBranch {
  type: 'branch';
  direction: 'horizontal' | 'vertical';
  ratio: number;
  children: [TemplateNode, TemplateNode];
}

export type TemplateNode = TemplateLeaf | TemplateBranch;

export interface Template {
  name: string;
  cwd: string;
  splitLayout: TemplateNode | null;
}
```

Note: Import `SplitNode` from the renderer store types won't work (circular). Instead, define `SplitNode` in `shared/types.ts` and have the renderer store types re-export it.

Actually, simpler: move `SplitNode`, `SplitLeaf`, `SplitBranch`, `SplitDirection` from `src/renderer/store/types.ts` into `src/shared/types.ts` so both main and renderer can use them. Update the children type to `[SplitNode, SplitNode]` (tuple).

- [ ] **Step 2: Update store types**

In `src/renderer/store/types.ts`:
- Remove `SplitLeaf`, `SplitBranch`, `SplitNode`, `SplitDirection` (now in shared/types)
- Import them from `../../shared/types`
- Add to `StoreState`:

```typescript
  terminalStatuses: Record<string, TerminalActivityStatus>;
  templates: Template[];
  resumeSessions: ResumeSession[] | null; // null = not scanned yet
```

- Add new types:

```typescript
export type TerminalActivityStatus = 'idle' | 'running' | 'success' | 'error' | 'waiting';

export interface ResumeSession {
  sessionName: string;
  cwd: string;
  folderName: string;
  selected: boolean;
}
```

- Add to `StoreActions`:

```typescript
  setTerminalStatus: (id: string, status: TerminalActivityStatus) => void;
  setTemplates: (templates: Template[]) => void;
  setResumeSessions: (sessions: ResumeSession[] | null) => void;
  toggleResumeSession: (sessionName: string) => void;
  getGroupSplitLayout: (groupId: string) => SplitNode | null;
  setGroupSplitLayout: (groupId: string, layout: SplitNode | null) => void;
```

- [ ] **Step 3: Update store implementation**

In `src/renderer/store/index.ts`:
- Remove top-level `splitLayout` from initial state
- Add `terminalStatuses: {}`, `templates: []`, `resumeSessions: null`
- Update `splitTerminal` to operate on the active group's `splitLayout`
- Update `setSplitLayout` and `updateSplitRatio` to operate per-group
- Add new action implementations:

```typescript
setTerminalStatus: (id, status) => set((s) => ({
  terminalStatuses: { ...s.terminalStatuses, [id]: status },
})),

setTemplates: (templates) => set({ templates }),

setResumeSessions: (sessions) => set({ resumeSessions: sessions }),

toggleResumeSession: (sessionName) => set((s) => ({
  resumeSessions: s.resumeSessions?.map((rs) =>
    rs.sessionName === sessionName ? { ...rs, selected: !rs.selected } : rs
  ) ?? null,
})),

getGroupSplitLayout: (groupId) => {
  return get().groups.find((g) => g.id === groupId)?.splitLayout ?? null;
},

setGroupSplitLayout: (groupId, layout) => set((s) => ({
  groups: s.groups.map((g) => g.id === groupId ? { ...g, splitLayout: layout } : g),
})),
```

- [ ] **Step 4: Update SessionStore for settings merge**

In `src/main/session-store.ts`, change `loadSettings`:

```typescript
async loadSettings(): Promise<Settings> {
  const saved = await this.readJson<Partial<Settings>>('settings.json', {});
  return { ...DEFAULT_SETTINGS, ...saved };
}
```

Add template methods:

```typescript
async loadTemplates(): Promise<Template[]> {
  return this.readJson('templates.json', []);
}

async saveTemplates(templates: Template[]): Promise<void> {
  await this.writeJson('templates.json', templates);
}
```

- [ ] **Step 5: Run tests, commit**

Run: `npx vitest run`
Expected: All existing tests pass (no breaking changes — just additions)

```bash
git add src/shared/types.ts src/renderer/store/ src/main/session-store.ts
git commit -m "feat: add shared types for split layout, activity monitor, templates, and resume"
```

---

### Task 2: Working Split Panes

**Files:**
- Modify: `src/renderer/components/TerminalArea.tsx`
- Modify: `src/renderer/components/SplitContainer.tsx`
- Modify: `src/renderer/App.tsx`
- Modify: `src/renderer/hooks/useShortcuts.ts`

- [ ] **Step 1: Update TerminalArea to render split tree from active group**

```typescript
// src/renderer/components/TerminalArea.tsx
export function TerminalArea({ onSpawnInCwd }: TerminalAreaProps) {
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const zenMode = useStore((s) => s.zenMode);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const hasTerminals = activeGroup && activeGroup.terminalIds.length > 0;
  const splitLayout = activeGroup?.splitLayout ?? null;

  if (!hasTerminals || !activeTerminalId) {
    return (
      <div className="d-terminal-area--empty">
        <div style={{ textAlign: 'center' }}>
          <p style={{ color: 'var(--text-dim)' }}>No terminal open</p>
          <p style={{ fontSize: 12, marginTop: 8, color: 'var(--text-dim)' }}>
            Use Quick Launch or press ⌘N
          </p>
        </div>
      </div>
    );
  }

  // Zen mode: single pane, full size
  if (zenMode) {
    return (
      <div className="d-terminal-area">
        <TerminalPane key={activeTerminalId} terminalId={activeTerminalId} />
      </div>
    );
  }

  // Split layout: render the tree
  if (splitLayout) {
    return (
      <div className="d-terminal-area">
        <SplitContainer node={splitLayout} path={[]} />
      </div>
    );
  }

  // Single pane
  return (
    <div className="d-terminal-area">
      <TerminalPane key={activeTerminalId} terminalId={activeTerminalId} />
    </div>
  );
}
```

- [ ] **Step 2: Update SplitContainer children type handling**

In `src/renderer/components/SplitContainer.tsx`, update to expect exactly 2 children (tuple). The existing code already accesses `node.children[0]` and `node.children[1]` so this is mostly a type fix.

- [ ] **Step 3: Wire Cmd+D to spawn terminal + update split tree**

In `src/renderer/App.tsx`, update the `onSplitHorizontal` and `onSplitVertical` handlers:

```typescript
onSplitHorizontal: async () => {
  const state = useStore.getState();
  const activeGroup = state.groups.find((g) => g.id === state.activeGroupId);
  if (!activeGroup || !state.activeTerminalId) return;

  // Spawn a new terminal in the same CWD
  const cwd = activeGroup.cwd || homedir;
  const newId = await pty.spawn({ cwd, command: '$SHELL' });
  addTerminal(activeGroup.id, { id: newId, command: '$SHELL', cwd, status: TerminalStatus.RUNNING });

  // Update split tree
  const currentLayout = activeGroup.splitLayout;
  if (!currentLayout) {
    // First split: wrap current + new in a branch
    state.setGroupSplitLayout(activeGroup.id, {
      type: 'branch',
      direction: 'horizontal',
      ratio: 0.5,
      children: [
        { type: 'leaf', terminalId: state.activeTerminalId },
        { type: 'leaf', terminalId: newId },
      ],
    });
  } else {
    // Deeper split: find the leaf with activeTerminalId and replace it with a branch
    const newLayout = splitLeafInTree(currentLayout, state.activeTerminalId, newId, 'horizontal');
    state.setGroupSplitLayout(activeGroup.id, newLayout);
  }
},
```

Add a helper function `splitLeafInTree` in App.tsx (or a utils file):

```typescript
function splitLeafInTree(
  node: SplitNode, targetId: string, newId: string, direction: SplitDirection
): SplitNode {
  if (node.type === 'leaf') {
    if (node.terminalId === targetId) {
      return {
        type: 'branch',
        direction,
        ratio: 0.5,
        children: [
          { type: 'leaf', terminalId: targetId },
          { type: 'leaf', terminalId: newId },
        ],
      };
    }
    return node;
  }
  return {
    ...node,
    children: [
      splitLeafInTree(node.children[0], targetId, newId, direction),
      splitLeafInTree(node.children[1], targetId, newId, direction),
    ] as [SplitNode, SplitNode],
  };
}
```

- [ ] **Step 4: Wire Cmd+W to collapse split tree**

Add a helper `removeLeafFromTree`:

```typescript
function removeLeafFromTree(node: SplitNode, targetId: string): SplitNode | null {
  if (node.type === 'leaf') {
    return node.terminalId === targetId ? null : node;
  }
  const left = removeLeafFromTree(node.children[0], targetId);
  const right = removeLeafFromTree(node.children[1], targetId);
  if (!left) return right;
  if (!right) return left;
  return { ...node, children: [left, right] as [SplitNode, SplitNode] };
}
```

Update `onCloseTerminal` in useShortcuts wiring:

```typescript
onCloseTerminal: () => {
  const state = useStore.getState();
  const id = state.activeTerminalId;
  if (!id) return;

  const group = state.groups.find((g) => g.id === state.activeGroupId);
  if (!group) return;

  // Kill PTY
  pty.kill(id);
  removeTerminal(id);

  // Update split tree
  if (group.splitLayout) {
    const newLayout = removeLeafFromTree(group.splitLayout, id);
    state.setGroupSplitLayout(group.id, newLayout);
  }

  // Select another terminal if available
  const remaining = group.terminalIds.filter((t) => t !== id);
  if (remaining.length > 0) {
    state.setActiveTerminal(remaining[0]);
  }
},
```

- [ ] **Step 5: Verify splits work**

Run: `npm run build && npm start`
Test: Open a folder, spawn a shell, Cmd+D to split, Cmd+W to close a pane.

- [ ] **Step 6: Commit**

```bash
git add src/renderer/components/TerminalArea.tsx src/renderer/components/SplitContainer.tsx src/renderer/App.tsx src/renderer/hooks/useShortcuts.ts
git commit -m "feat: wire working split panes with Cmd+D split and Cmd+W collapse"
```

---

### Task 3: Terminal Activity Monitor

**Files:**
- Create: `src/main/terminal-monitor.ts`
- Create: `tests/main/terminal-monitor.test.ts`
- Modify: `src/main/ipc.ts`
- Modify: `src/main/preload.ts`
- Modify: `src/renderer/App.tsx`
- Modify: `src/renderer/components/TerminalEntry.tsx`
- Modify: `src/renderer/styles/dispatch.css`

- [ ] **Step 1: Write failing tests for TerminalMonitor**

```typescript
// tests/main/terminal-monitor.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { TerminalMonitor } from '../../src/main/terminal-monitor';

describe('TerminalMonitor', () => {
  let monitor: TerminalMonitor;
  let statusCallback: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    statusCallback = vi.fn();
    monitor = new TerminalMonitor(statusCallback);
  });

  it('detects running state on output', () => {
    monitor.onData('t1', 'some output text');
    expect(statusCallback).toHaveBeenCalledWith('t1', 'running');
  });

  it('detects error patterns', () => {
    monitor.onData('t1', 'Error: something failed');
    expect(statusCallback).toHaveBeenCalledWith('t1', 'error');
  });

  it('detects success patterns', () => {
    monitor.onData('t1', 'All tests passed ✓');
    expect(statusCallback).toHaveBeenCalledWith('t1', 'success');
  });

  it('detects waiting patterns', () => {
    monitor.onData('t1', 'Do you want to continue? (y/n)');
    expect(statusCallback).toHaveBeenCalledWith('t1', 'waiting');
  });

  it('transitions to idle after timeout', async () => {
    monitor.onData('t1', 'some output');
    // Fast-forward idle timer
    await new Promise((r) => setTimeout(r, 3500));
    expect(statusCallback).toHaveBeenCalledWith('t1', 'idle');
  });

  it('strips ANSI codes before matching', () => {
    monitor.onData('t1', '\x1b[31mError:\x1b[0m bad thing');
    expect(statusCallback).toHaveBeenCalledWith('t1', 'error');
  });

  it('cleanup removes terminal timers', () => {
    monitor.onData('t1', 'output');
    monitor.cleanup('t1');
    // Should not throw or leak
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx vitest run tests/main/terminal-monitor.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement TerminalMonitor**

```typescript
// src/main/terminal-monitor.ts
export type ActivityStatus = 'idle' | 'running' | 'success' | 'error' | 'waiting';
type StatusCallback = (terminalId: string, status: ActivityStatus) => void;

// Strip ANSI escape codes
function stripAnsi(str: string): string {
  return str.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '');
}

const PATTERNS: { status: ActivityStatus; regex: RegExp }[] = [
  { status: 'error', regex: /\berror\b[^_]|\bfailed\b|\bFAIL\b|[✗❌]|exit code [1-9]/i },
  { status: 'success', regex: /[✓✅]|\bpassed\b|\bcompleted\b|Done!|All.*passed/i },
  { status: 'waiting', regex: /\?\s*$|\(y\/n\)|Continue\?|\bapprove\b|\bpermission\b/i },
];

const IDLE_TIMEOUT = 3000;
const DEBOUNCE_MS = 100;

export class TerminalMonitor {
  private buffers = new Map<string, string>();
  private idleTimers = new Map<string, NodeJS.Timeout>();
  private debounceTimers = new Map<string, NodeJS.Timeout>();
  private lastStatus = new Map<string, ActivityStatus>();
  private callback: StatusCallback;

  constructor(callback: StatusCallback) {
    this.callback = callback;
  }

  onData(terminalId: string, data: string): void {
    // Update buffer (keep last 500 chars)
    const existing = this.buffers.get(terminalId) || '';
    const updated = (existing + data).slice(-500);
    this.buffers.set(terminalId, updated);

    // Strip ANSI and match patterns
    const clean = stripAnsi(data);
    let detected: ActivityStatus = 'running';

    for (const { status, regex } of PATTERNS) {
      if (regex.test(clean)) {
        detected = status;
        break;
      }
    }

    // Emit with debounce
    this.emitDebounced(terminalId, detected);

    // Reset idle timer
    this.resetIdleTimer(terminalId);
  }

  cleanup(terminalId: string): void {
    this.buffers.delete(terminalId);
    const idle = this.idleTimers.get(terminalId);
    if (idle) clearTimeout(idle);
    this.idleTimers.delete(terminalId);
    const debounce = this.debounceTimers.get(terminalId);
    if (debounce) clearTimeout(debounce);
    this.debounceTimers.delete(terminalId);
    this.lastStatus.delete(terminalId);
  }

  private emitDebounced(terminalId: string, status: ActivityStatus): void {
    const existing = this.debounceTimers.get(terminalId);
    if (existing) clearTimeout(existing);

    this.debounceTimers.set(terminalId, setTimeout(() => {
      if (this.lastStatus.get(terminalId) !== status) {
        this.lastStatus.set(terminalId, status);
        this.callback(terminalId, status);
      }
    }, DEBOUNCE_MS));
  }

  private resetIdleTimer(terminalId: string): void {
    const existing = this.idleTimers.get(terminalId);
    if (existing) clearTimeout(existing);

    this.idleTimers.set(terminalId, setTimeout(() => {
      this.emitDebounced(terminalId, 'idle');
    }, IDLE_TIMEOUT));
  }
}
```

- [ ] **Step 4: Run tests**

Run: `npx vitest run tests/main/terminal-monitor.test.ts`
Expected: PASS (all 7 tests)

- [ ] **Step 5: Wire monitor into IPC**

In `src/main/ipc.ts`, after PTY event forwarding:

```typescript
import { TerminalMonitor } from './terminal-monitor';
import { Notification } from 'electron';

const monitor = new TerminalMonitor((terminalId, status) => {
  const win = BrowserWindow.getAllWindows()[0];
  win?.webContents.send('monitor:status', terminalId, status);

  // Desktop notifications for success/error
  if (status === 'success' || status === 'error') {
    store.loadSettings().then((settings) => {
      if (!settings.notificationsEnabled) return;
      new Notification({
        title: `Dispatch: ${status === 'success' ? 'Task Complete' : 'Error Detected'}`,
        body: `Terminal ${terminalId.slice(0, 8)}...`,
      }).show();
    });
  }
});

// Tap PTY data into monitor
ptyManager.onData((id, data) => {
  monitor.onData(id, data);
});
```

In `src/main/preload.ts`, add:

```typescript
monitor: {
  onStatus: (cb: (id: string, status: string) => void) => {
    ipcRenderer.on('monitor:status', (_event, id, status) => cb(id, status));
  },
},
```

- [ ] **Step 6: Wire monitor status into renderer**

In `src/renderer/App.tsx`, add useEffect:

```typescript
useEffect(() => {
  window.dispatch?.monitor?.onStatus((id: string, status: string) => {
    useStore.getState().setTerminalStatus(id, status as TerminalActivityStatus);
  });
}, []);
```

- [ ] **Step 7: Update TerminalEntry to show status dot**

In `src/renderer/components/TerminalEntry.tsx`, replace the static dot with the activity-based one:

```typescript
const activityStatus = useStore((s) => s.terminalStatuses[terminalId]) || 'idle';

const statusColors: Record<string, string> = {
  idle: '#555555',
  running: 'var(--accent-blue-light)',
  success: 'var(--accent-green)',
  error: 'var(--accent-primary)',
  waiting: 'var(--accent-yellow)',
};

const dotColor = statusColors[activityStatus] || '#555555';
```

- [ ] **Step 8: Add CSS for pulsing dot**

In `src/renderer/styles/dispatch.css`:

```css
@keyframes d-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

.d-entry__dot--running {
  animation: d-pulse 1.5s ease-in-out infinite;
}
```

- [ ] **Step 9: Commit**

```bash
git add src/main/terminal-monitor.ts tests/main/terminal-monitor.test.ts src/main/ipc.ts src/main/preload.ts src/renderer/App.tsx src/renderer/components/TerminalEntry.tsx src/renderer/styles/dispatch.css
git commit -m "feat: add terminal activity monitor with status dots and notifications"
```

---

### Task 4: Session Templates

**Files:**
- Create: `src/renderer/components/SaveTemplateDialog.tsx`
- Modify: `src/main/ipc.ts`
- Modify: `src/main/preload.ts`
- Modify: `src/renderer/App.tsx`
- Modify: `src/renderer/hooks/useShortcuts.ts`
- Modify: `src/renderer/components/CommandPalette.tsx`
- Modify: `src/renderer/components/SettingsPanel.tsx`
- Modify: `src/renderer/styles/dispatch.css`

- [ ] **Step 1: Add template IPC handlers**

In `src/main/ipc.ts`:

```typescript
ipcMain.handle('templates:load', async () => {
  return store.loadTemplates();
});

ipcMain.handle('templates:save', async (_event, templates) => {
  await store.saveTemplates(templates);
});
```

In `src/main/preload.ts`:

```typescript
templates: {
  load: () => ipcRenderer.invoke('templates:load'),
  save: (templates: unknown) => ipcRenderer.invoke('templates:save', templates),
},
```

- [ ] **Step 2: Create SaveTemplateDialog component**

```typescript
// src/renderer/components/SaveTemplateDialog.tsx
import React, { useState, useRef, useEffect } from 'react';

interface SaveTemplateDialogProps {
  open: boolean;
  defaultName: string;
  onSave: (name: string) => void;
  onClose: () => void;
}

export function SaveTemplateDialog({ open, defaultName, onSave, onClose }: SaveTemplateDialogProps) {
  const [name, setName] = useState(defaultName);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (open) {
      setName(defaultName);
      setTimeout(() => inputRef.current?.select(), 50);
    }
  }, [open, defaultName]);

  if (!open) return null;

  return (
    <div className="d-overlay" onClick={onClose}>
      <div className="d-overlay__backdrop" />
      <div className="d-overlay__panel" onClick={(e) => e.stopPropagation()} style={{ width: 400 }}>
        <div className="d-settings__header">
          <span className="d-settings__title">Save Template</span>
          <button className="d-settings__close" onClick={onClose}>Esc</button>
        </div>
        <div style={{ padding: 'var(--space-4) var(--space-6)' }}>
          <label className="d-settings__label" style={{ display: 'block', marginBottom: 8 }}>
            Template Name
          </label>
          <input
            ref={inputRef}
            className="d-settings__input d-settings__input--wide"
            style={{ width: '100%' }}
            value={name}
            onChange={(e) => setName(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && name.trim()) onSave(name.trim());
              if (e.key === 'Escape') onClose();
            }}
          />
          <button
            className="d-welcome__button"
            style={{ width: '100%', marginTop: 12 }}
            onClick={() => name.trim() && onSave(name.trim())}
          >
            Save Template
          </button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Build the save/restore logic in App.tsx**

Add helper to convert live split tree to template tree (replace terminalIds with commands):

```typescript
function splitNodeToTemplate(node: SplitNode, terminals: Record<string, TerminalEntry>): TemplateNode {
  if (node.type === 'leaf') {
    const term = terminals[node.terminalId];
    return { type: 'leaf', command: term?.command || '$SHELL' };
  }
  return {
    type: 'branch',
    direction: node.direction,
    ratio: node.ratio,
    children: [
      splitNodeToTemplate(node.children[0], terminals),
      splitNodeToTemplate(node.children[1], terminals),
    ] as [TemplateNode, TemplateNode],
  };
}
```

Add template restore helper (spawns terminals and builds split tree):

```typescript
async function restoreTemplate(
  template: Template,
  pty: any,
  addTerminal: Function,
  findOrCreateGroup: Function,
  setActiveTerminal: Function,
): Promise<void> {
  const groupId = findOrCreateGroup(template.cwd);
  useStore.getState().setActiveGroup(groupId);

  if (!template.splitLayout) {
    // Single terminal template
    const id = await pty.spawn({ cwd: template.cwd, command: '$SHELL' });
    addTerminal(groupId, { id, command: '$SHELL', cwd: template.cwd, status: TerminalStatus.RUNNING });
    setActiveTerminal(id);
    return;
  }

  // Walk template tree, spawn terminals, build live split tree
  async function spawnFromTemplate(tNode: TemplateNode): Promise<SplitNode> {
    if (tNode.type === 'leaf') {
      const id = await pty.spawn({ cwd: template.cwd, command: tNode.command });
      addTerminal(groupId, { id, command: tNode.command, cwd: template.cwd, status: TerminalStatus.RUNNING });
      return { type: 'leaf', terminalId: id };
    }
    const [left, right] = await Promise.all([
      spawnFromTemplate(tNode.children[0]),
      spawnFromTemplate(tNode.children[1]),
    ]);
    return { type: 'branch', direction: tNode.direction, ratio: tNode.ratio, children: [left, right] as [SplitNode, SplitNode] };
  }

  const liveLayout = await spawnFromTemplate(template.splitLayout);
  useStore.getState().setGroupSplitLayout(groupId, liveLayout);

  // Select the first leaf
  function firstLeaf(n: SplitNode): string {
    return n.type === 'leaf' ? n.terminalId : firstLeaf(n.children[0]);
  }
  setActiveTerminal(firstLeaf(liveLayout));
}
```

- [ ] **Step 4: Wire Cmd+Shift+S to save template**

In `useShortcuts.ts`, add to handler interface and implementation:

```typescript
// Interface:
onSaveTemplate: () => void;

// Handler:
if (meta && e.shiftKey && (e.key === 's' || e.key === 'S')) {
  e.preventDefault();
  handlers.onSaveTemplate();
  return;
}
```

In App.tsx:

```typescript
const [saveTemplateOpen, setSaveTemplateOpen] = React.useState(false);

// In useShortcuts:
onSaveTemplate: () => setSaveTemplateOpen(true),

// Save handler:
const handleSaveTemplate = async (name: string) => {
  const state = useStore.getState();
  const group = state.groups.find((g) => g.id === state.activeGroupId);
  if (!group) return;

  const splitLayout = group.splitLayout
    ? splitNodeToTemplate(group.splitLayout, state.terminals)
    : group.terminalIds.length === 1
    ? { type: 'leaf' as const, command: state.terminals[group.terminalIds[0]]?.command || '$SHELL' }
    : null;

  const template: Template = { name, cwd: group.cwd || '/', splitLayout };
  const templates = [...state.templates, template];
  state.setTemplates(templates);
  await window.dispatch.templates.save(templates);
  setSaveTemplateOpen(false);
};
```

- [ ] **Step 5: Add templates to welcome screen and command palette**

In App.tsx welcome screen, add template list:

```typescript
{templates.length > 0 && (
  <div style={{ marginTop: 24, width: 400 }}>
    <div className="d-quicklaunch__label">Saved Templates</div>
    {templates.map((t, i) => (
      <button key={i} className="d-entry" style={{ width: '100%', marginBottom: 4 }}
        onClick={() => restoreTemplate(t, pty, addTerminal, findOrCreateGroup, setActiveTerminal)}>
        <div className="d-entry__header">
          <span className="d-entry__dot" style={{ backgroundColor: 'var(--accent-blue-light)' }} />
          <span className="d-entry__name">{t.name}</span>
        </div>
        <div className="d-entry__command">{t.cwd}</div>
      </button>
    ))}
  </div>
)}
```

In `CommandPalette.tsx`, add templates to the search items below presets.

- [ ] **Step 6: Add template management to SettingsPanel**

Add a "Templates" section with list + delete button per template.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add session templates with save/restore and command palette integration"
```

---

### Task 5: Auto-Resume

**Files:**
- Modify: `src/main/pty-manager.ts`
- Create: `src/renderer/components/ResumeModal.tsx`
- Modify: `src/main/ipc.ts`
- Modify: `src/main/preload.ts`
- Modify: `src/renderer/App.tsx`
- Modify: `src/renderer/styles/dispatch.css`

- [ ] **Step 1: Update PTY manager with readable session names**

In `src/main/pty-manager.ts`, change session naming:

```typescript
// Replace: const sessionName = `dispatch-${id}`;
// With:
private sessionCounter = new Map<string, number>();

private getSessionName(cwd: string): string {
  const folderName = cwd.split('/').pop() || 'unknown';
  // Sanitize for tmux (no dots or colons)
  const safe = folderName.replace(/[.:]/g, '-');
  const count = this.sessionCounter.get(safe) || 0;
  this.sessionCounter.set(safe, count + 1);
  return `dispatch-${safe}-${count}`;
}
```

Add a method to list existing dispatch sessions:

```typescript
static listDispatchSessions(): { name: string; cwd: string }[] {
  try {
    const { execSync } = require('child_process');
    const sessions = execSync(
      'tmux list-sessions -F "#{session_name}" 2>/dev/null',
      { encoding: 'utf-8', timeout: 3000 }
    ).trim().split('\n').filter((s: string) => s.startsWith('dispatch-'));

    return sessions.map((name: string) => {
      let cwd = '';
      try {
        cwd = execSync(
          `tmux display-message -t "${name}" -p "#{pane_current_path}" 2>/dev/null`,
          { encoding: 'utf-8', timeout: 2000 }
        ).trim();
      } catch { cwd = ''; }
      return { name, cwd };
    });
  } catch { return []; }
}

static killSession(name: string): void {
  try {
    execSync(`tmux kill-session -t "${name}" 2>/dev/null`, { timeout: 2000 });
  } catch {}
}
```

- [ ] **Step 2: Add resume IPC handlers**

In `src/main/ipc.ts`:

```typescript
ipcMain.handle('resume:scan', async () => {
  return PtyManager.listDispatchSessions();
});

ipcMain.handle('resume:restore', async (_event, sessionName: string) => {
  // Spawn PTY that attaches to existing tmux session
  const id = randomUUID();
  // We need to pass session name to pty manager for attach
  return ptyManager.attachSession(sessionName);
});

ipcMain.handle('resume:cleanup', async (_event, sessionNames: string[]) => {
  for (const name of sessionNames) {
    PtyManager.killSession(name);
  }
});
```

Add `attachSession` to PtyManager:

```typescript
attachSession(sessionName: string): string {
  const id = randomUUID();
  const env = { ...process.env, TERM: 'xterm-256color', COLORTERM: 'truecolor' } as Record<string, string>;

  const term = pty.spawn('tmux', ['attach-session', '-t', sessionName], {
    name: 'xterm-256color',
    cols: 80,
    rows: 24,
    cwd: process.env.HOME || '/',
    env,
  });

  this.terminals.set(id, term);
  term.onData((data) => { for (const cb of this.dataCallbacks) cb(id, data); });
  term.onExit(({ exitCode, signal }) => {
    this.terminals.delete(id);
    for (const cb of this.exitCallbacks) cb(id, exitCode ?? 0, signal ?? 0);
  });

  return id;
}
```

In preload:

```typescript
resume: {
  scan: () => ipcRenderer.invoke('resume:scan'),
  restore: (sessionName: string) => ipcRenderer.invoke('resume:restore', sessionName),
  cleanup: (sessionNames: string[]) => ipcRenderer.invoke('resume:cleanup', sessionNames),
},
```

- [ ] **Step 3: Create ResumeModal component**

```typescript
// src/renderer/components/ResumeModal.tsx
import React from 'react';
import { useStore } from '../store';

interface ResumeModalProps {
  onRestore: () => void;
  onFresh: () => void;
}

export function ResumeModal({ onRestore, onFresh }: ResumeModalProps) {
  const sessions = useStore((s) => s.resumeSessions);
  const toggleSession = useStore((s) => s.toggleResumeSession);

  if (!sessions || sessions.length === 0) return null;

  // Group sessions by folder
  const grouped = new Map<string, typeof sessions>();
  for (const s of sessions) {
    const key = s.folderName;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key)!.push(s);
  }

  return (
    <div className="d-overlay d-overlay--center">
      <div className="d-overlay__backdrop" />
      <div className="d-overlay__panel" style={{ width: 500 }}>
        <div className="d-settings__header">
          <span className="d-settings__title">Restore Previous Sessions</span>
        </div>
        <div style={{ padding: 'var(--space-4) var(--space-6)', maxHeight: '60vh', overflowY: 'auto' }}>
          <p style={{ fontSize: 12, color: 'var(--text-muted)', marginBottom: 16 }}>
            Found {sessions.length} session{sessions.length !== 1 ? 's' : ''} from your last run:
          </p>
          {Array.from(grouped.entries()).map(([folder, items]) => (
            <div key={folder} style={{ marginBottom: 12 }}>
              <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 4 }}>
                {folder} ({items.length})
              </div>
              {items.map((s) => (
                <label key={s.sessionName} className="d-entry" style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={s.selected}
                    onChange={() => toggleSession(s.sessionName)}
                  />
                  <div>
                    <div className="d-entry__name" style={{ fontSize: 11 }}>{s.sessionName}</div>
                    <div className="d-entry__command">{s.cwd}</div>
                  </div>
                </label>
              ))}
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 8, padding: 'var(--space-4) var(--space-6)', borderTop: '1px solid var(--border-default)' }}>
          <button className="d-welcome__button" style={{ flex: 1 }} onClick={onRestore}>
            Restore Selected
          </button>
          <button className="d-context-menu__item" style={{ flex: 1, textAlign: 'center', padding: '10px 0' }} onClick={onFresh}>
            Start Fresh
          </button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Wire resume flow into App.tsx**

On mount, scan for sessions:

```typescript
const [showResume, setShowResume] = React.useState(false);

useEffect(() => {
  window.dispatch?.resume?.scan().then((sessions: any[]) => {
    if (sessions && sessions.length > 0) {
      const mapped = sessions.map((s) => ({
        sessionName: s.name,
        cwd: s.cwd,
        folderName: s.cwd.split('/').pop() || s.name,
        selected: true,
      }));
      useStore.getState().setResumeSessions(mapped);
      setShowResume(true);
    }
  });
}, []);

const handleRestore = async () => {
  const sessions = useStore.getState().resumeSessions?.filter((s) => s.selected) || [];
  for (const session of sessions) {
    const groupId = findOrCreateGroup(session.cwd);
    const id = await window.dispatch.resume.restore(session.sessionName);
    addTerminal(groupId, { id, command: 'tmux (restored)', cwd: session.cwd, status: TerminalStatus.RUNNING });
    setActiveTerminal(id);
  }
  setShowResume(false);
  useStore.getState().setResumeSessions(null);
};

const handleFresh = async () => {
  const sessions = useStore.getState().resumeSessions || [];
  await window.dispatch.resume.cleanup(sessions.map((s) => s.sessionName));
  setShowResume(false);
  useStore.getState().setResumeSessions(null);
};
```

Render the modal:

```typescript
{showResume && <ResumeModal onRestore={handleRestore} onFresh={handleFresh} />}
```

- [ ] **Step 5: Add autoplay policy for notification sounds**

In `src/main/index.ts`, before `app.whenReady()`:

```typescript
app.commandLine.appendSwitch('autoplay-policy', 'no-user-gesture-required');
```

- [ ] **Step 6: Verify full flow**

Run: `npm run build && npm start`
1. Open a folder, spawn terminals
2. Close Dispatch
3. Reopen Dispatch — should see resume modal with sessions listed
4. Click "Restore Selected" — terminals reconnect

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add auto-resume with tmux session detection and restore modal"
```

---

### Task 6: Sound Files + Notification Settings

**Files:**
- Create: `src/assets/success.mp3`, `src/assets/error.mp3`
- Modify: `src/renderer/components/SettingsPanel.tsx`
- Modify: `webpack.renderer.config.ts`

- [ ] **Step 1: Create placeholder sound files**

Generate minimal beep sounds using a script or download royalty-free files. For now, create silent placeholder MP3s that can be replaced later:

```bash
# Create minimal valid MP3 files (1 second of silence)
# Using ffmpeg if available, otherwise create empty files
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 0.5 -q:a 9 src/assets/success.mp3 2>/dev/null || touch src/assets/success.mp3
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 0.5 -q:a 9 src/assets/error.mp3 2>/dev/null || touch src/assets/error.mp3
```

- [ ] **Step 2: Add file-loader rule to webpack for .mp3**

In `webpack.renderer.config.ts`, add to rules:

```typescript
{ test: /\.mp3$/, type: 'asset/resource' },
```

- [ ] **Step 3: Add notification/sound toggles to SettingsPanel**

Add a new "Notifications" section with two toggles:

```typescript
<div className="d-settings__section">
  <h3 className="d-settings__section-title">Notifications</h3>
  <div className="d-settings__row">
    <span className="d-settings__label">Desktop Notifications</span>
    <input type="checkbox"
      checked={settings.notificationsEnabled}
      onChange={(e) => setSettings({ ...settings, notificationsEnabled: e.target.checked })}
    />
  </div>
  <div className="d-settings__row">
    <span className="d-settings__label">Sound Effects</span>
    <input type="checkbox"
      checked={settings.soundEnabled}
      onChange={(e) => setSettings({ ...settings, soundEnabled: e.target.checked })}
    />
  </div>
</div>
```

Also add a "Templates" section listing saved templates with delete buttons.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add notification sounds and settings toggles"
```

---

### Task 7: Integration Testing

**Files:** None (manual verification)

- [ ] **Step 1: Full build + test suite**

```bash
npm run build && npx vitest run
```

Expected: Clean build, all tests pass.

- [ ] **Step 2: Test split panes**

1. Open folder → spawn shell → `Cmd+D` → second pane appears
2. `Cmd+Shift+D` in one pane → vertical split
3. `Cmd+W` → pane closes, sibling expands
4. Switch tabs → split layout is per-tab

- [ ] **Step 3: Test activity monitor**

1. In a shell, run `echo "All tests passed ✓"` → dot should turn green
2. Run `echo "Error: something failed"` → dot should turn red
3. Wait 3+ seconds → dot should go gray (idle)
4. Check desktop notification appeared

- [ ] **Step 4: Test templates**

1. Set up a split layout with 2 Claude Code + 1 Shell
2. `Cmd+Shift+S` → save as "MyProject"
3. Close all tabs
4. Welcome screen shows "MyProject" template
5. Click it → layout restores with 3 terminals in splits

- [ ] **Step 5: Test auto-resume**

1. Open folder, spawn terminals
2. Quit Dispatch completely
3. Reopen → resume modal shows sessions
4. Click "Restore Selected" → terminals reconnect with scrollback

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore: integration testing complete for power features"
```
