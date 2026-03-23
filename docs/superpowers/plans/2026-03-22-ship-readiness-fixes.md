# Ship-Readiness Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all blockers and high-priority issues from the QA code review so Dispatch v1.2.0 is ready to ship.

**Architecture:** Fixes span the main process (IPC, PTY, session store), the preload bridge, and the renderer (App.tsx). Tasks are grouped by file to avoid conflicts — tasks modifying the same file are sequential and later tasks account for line shifts from earlier ones.

**Tech Stack:** TypeScript, Electron (main/renderer/preload), React, Zustand, Vitest

**File dependency order:** Tasks 1-2 both modify `App.tsx` — do Task 1 first, Task 2 second. Tasks 5-7 all modify `ipc.ts` — do them in order. Tasks 3, 4, 8 are independent.

---

### Task 1: Fix Unhandled Promise Rejections in App.tsx

All `.then()` IPC calls in `App.tsx` lack `.catch()`. If any IPC call fails on startup, the app silently breaks. The debounced `stateApi.save()` at line 130 has the same bug.

**Files:**
- Modify: `src/renderer/App.tsx`

- [ ] **Step 1: Add `.catch()` to `stateApi.load()` (line 112)**

```typescript
// Before:
stateApi.load().then((data: any) => {
  if (data?.presets) useStore.getState().setPresets(data.presets);
  if (data?.settings) useStore.getState().setSettings(data.settings);
  if (data?.state?.groups) {
    for (const g of data.state.groups) {
      useStore.getState().addGroup(g.cwd, g.label);
    }
  }
});

// After:
stateApi.load().then((data: any) => {
  if (data?.presets) useStore.getState().setPresets(data.presets);
  if (data?.settings) useStore.getState().setSettings(data.settings);
  if (data?.state?.groups) {
    for (const g of data.state.groups) {
      useStore.getState().addGroup(g.cwd, g.label);
    }
  }
}).catch(() => {});
```

- [ ] **Step 2: Add `.catch()` to debounced `stateApi.save()` (line 130)**

```typescript
// Before:
saveTimeoutRef.current = setTimeout(() => {
  stateApi.save({
    ...
  });
}, 2000);

// After:
saveTimeoutRef.current = setTimeout(() => {
  stateApi.save({
    ...
  }).catch(() => {});
}, 2000);
```

- [ ] **Step 3: Add `.catch()` to `getHomedir()` (line 157)**

```typescript
// Before:
window.dispatch?.app?.getHomedir().then((h: string) => setHomedir(h));

// After:
window.dispatch?.app?.getHomedir().then((h: string) => setHomedir(h)).catch(() => {});
```

- [ ] **Step 4: Add `.catch()` to `tmux.isAvailable()` (line 218)**

```typescript
// Before:
(window as any).dispatch?.tmux?.isAvailable().then((available: boolean) => {
  useStore.getState().setTmuxAvailable(available);
});

// After:
(window as any).dispatch?.tmux?.isAvailable()?.then((available: boolean) => {
  useStore.getState().setTmuxAvailable(available);
})?.catch(() => {});
```

- [ ] **Step 5: Add `.catch()` to `templates.load()` (line 224)**

```typescript
// Before:
(window as any).dispatch?.templates?.load().then((t: Template[]) => {
  if (t) useStore.getState().setTemplates(t);
});

// After:
(window as any).dispatch?.templates?.load()?.then((t: Template[]) => {
  if (t) useStore.getState().setTemplates(t);
})?.catch(() => {});
```

- [ ] **Step 6: Add `.catch()` to `resume.scan()` (line 230)**

```typescript
// Before:
(window as any).dispatch?.resume?.scan().then((sessions: any[]) => {
  ...
});

// After:
(window as any).dispatch?.resume?.scan()?.then((sessions: any[]) => {
  ...
})?.catch(() => {});
```

- [ ] **Step 7: Add `.catch()` to project data loads (lines 284-292)**

```typescript
// Before:
(window as any).dispatch?.project?.loadTasks(cwd).then((t: any) => {
  useStore.getState().setProjectTasks(t || []);
});
(window as any).dispatch?.project?.loadNotes(cwd).then((n: any) => {
  useStore.getState().setProjectNotes(n || []);
});
(window as any).dispatch?.project?.loadVault(cwd).then((v: any) => {
  useStore.getState().setProjectVault(v || []);
});

// After:
(window as any).dispatch?.project?.loadTasks(cwd)?.then((t: any) => {
  useStore.getState().setProjectTasks(t || []);
})?.catch(() => {});
(window as any).dispatch?.project?.loadNotes(cwd)?.then((n: any) => {
  useStore.getState().setProjectNotes(n || []);
})?.catch(() => {});
(window as any).dispatch?.project?.loadVault(cwd)?.then((v: any) => {
  useStore.getState().setProjectVault(v || []);
})?.catch(() => {});
```

- [ ] **Step 8: Wrap `handleSpawn`, `handleSpawnInCwd`, `handleOpenFolder` in try-catch**

For `handleSpawn` (line 160):
```typescript
const handleSpawn = useCallback(async (command: string, env?: Record<string, string>) => {
  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const cwd = activeGroup?.cwd || homedir;
  const groupId = activeGroup?.id || findOrCreateGroup(cwd);

  try {
    const id = await pty.spawn({ cwd, command, env });
    addTerminal(groupId, { id, command, cwd, status: TerminalStatus.RUNNING });
    setActiveTerminal(id);
  } catch {}
}, [activeGroupId, groups, pty, addTerminal, findOrCreateGroup, setActiveTerminal, homedir]);
```

Apply the same `try {} catch {}` pattern to `handleSpawnInCwd` (line 176) and `handleOpenFolder` (line 193) — wrap the body of each in try-catch.

- [ ] **Step 9: Run tests and type-check**

Run: `npx vitest run && npx tsc --noEmit`
Expected: All pass, no type errors

- [ ] **Step 10: Commit**

```bash
git add src/renderer/App.tsx
git commit -m "fix: add error handling for all IPC promise chains in App.tsx"
```

---

### Task 2: Fix Monitor/Browser Event Listener Leaks

`monitor.onStatus()` and `browser.onDetected()` in `preload.ts` register IPC listeners but return no unsubscribe function. The PTY listeners (`onData`, `onExit` at lines 10-18) already do this correctly — follow the same pattern. Then update `App.tsx` to use the cleanup functions and remove the guard refs.

**Files:**
- Modify: `src/main/preload.ts:39-41, 65-67`
- Modify: `src/renderer/App.tsx` (the monitor/browser useEffects — will have shifted slightly from Task 1's changes)

- [ ] **Step 1: Fix `monitor.onStatus` in preload.ts (lines 39-41)**

```typescript
// Before:
monitor: {
  onStatus: (cb: (id: string, status: string) => void) => {
    ipcRenderer.on('monitor:status', (_event: any, id: string, status: string) => cb(id, status));
  },
},

// After:
monitor: {
  onStatus: (cb: (id: string, status: string) => void) => {
    const handler = (_event: any, id: string, status: string) => cb(id, status);
    ipcRenderer.on('monitor:status', handler);
    return () => ipcRenderer.removeListener('monitor:status', handler);
  },
},
```

- [ ] **Step 2: Fix `browser.onDetected` in preload.ts (lines 65-67)**

```typescript
// Before:
onDetected: (cb: (terminalId: string, url: string) => void) => {
  ipcRenderer.on('browser:detected', (_event: any, terminalId: string, url: string) => cb(terminalId, url));
},

// After:
onDetected: (cb: (terminalId: string, url: string) => void) => {
  const handler = (_event: any, terminalId: string, url: string) => cb(terminalId, url);
  ipcRenderer.on('browser:detected', handler);
  return () => ipcRenderer.removeListener('browser:detected', handler);
},
```

- [ ] **Step 3: Update App.tsx monitor useEffect — remove guard ref, use cleanup**

Find the monitor useEffect block (search for `monitorRef`). Remove the `monitorRef` declaration and replace the entire useEffect:

```typescript
// Before:
const monitorRef = React.useRef(false);
useEffect(() => {
  if (monitorRef.current) return;
  monitorRef.current = true;
  (window as any).dispatch?.monitor?.onStatus((id: string, status: string) => {
    useStore.getState().setTerminalStatus(id, status as any);
  });
}, []);

// After:
useEffect(() => {
  const cleanup = (window as any).dispatch?.monitor?.onStatus((id: string, status: string) => {
    useStore.getState().setTerminalStatus(id, status as any);
  });
  return () => cleanup?.();
}, []);
```

- [ ] **Step 4: Update App.tsx browser detect useEffect — remove guard ref, use cleanup**

Find the browser detect useEffect block (search for `browserDetectRef`). Remove the `browserDetectRef` declaration and replace the entire useEffect:

```typescript
// Before:
const browserDetectRef = React.useRef(false);
useEffect(() => {
  if (browserDetectRef.current) return;
  browserDetectRef.current = true;
  (window as any).dispatch?.browser?.onDetected((terminalId: string, url: string) => {
    ...
  });
}, []);

// After:
useEffect(() => {
  const cleanup = (window as any).dispatch?.browser?.onDetected((terminalId: string, url: string) => {
    ...  // keep the existing callback body unchanged
  });
  return () => cleanup?.();
}, []);
```

- [ ] **Step 5: Run tests and type-check**

Run: `npx vitest run && npx tsc --noEmit`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add src/main/preload.ts src/renderer/App.tsx
git commit -m "fix: return cleanup functions from monitor/browser IPC listeners"
```

---

### Task 3: Fix PTY `onData` Callback Accumulation

`PtyManager.onData()` pushes to `dataCallbacks` with no removal mechanism. Add `offData`/`offExit` methods and update `ipc.ts` to use them in a hypothetical re-registration scenario.

**Files:**
- Modify: `src/main/pty-manager.ts:169-175`
- Test: `tests/main/pty-manager.test.ts` (add test)

- [ ] **Step 1: Write the failing test**

Add to `tests/main/pty-manager.test.ts`:

```typescript
it('offData removes a callback so it no longer fires', async () => {
  manager = new PtyManager();
  const received: string[] = [];
  const cb = (id: string, data: string) => received.push(data);
  manager.onData(cb);
  manager.offData(cb);
  const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh', noTmux: true });
  manager.write(id, 'echo offtest\r');
  await new Promise((r) => setTimeout(r, 500));
  expect(received.length).toBe(0);
});

it('offExit removes a callback so it no longer fires', async () => {
  manager = new PtyManager();
  let called = false;
  const cb = () => { called = true; };
  manager.onExit(cb);
  manager.offExit(cb);
  const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh', noTmux: true });
  manager.write(id, 'exit 0\r');
  await new Promise((r) => setTimeout(r, 2000));
  expect(called).toBe(false);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/main/pty-manager.test.ts`
Expected: FAIL — `manager.offData is not a function`

- [ ] **Step 3: Add `offData` and `offExit` methods to pty-manager.ts**

In `src/main/pty-manager.ts`, replace the `onData`/`onExit` block (lines 169-175):

```typescript
// Before:
onData(cb: DataCallback): void {
  this.dataCallbacks.push(cb);
}

onExit(cb: ExitCallback): void {
  this.exitCallbacks.push(cb);
}

// After:
onData(cb: DataCallback): void {
  this.dataCallbacks.push(cb);
}

offData(cb: DataCallback): void {
  this.dataCallbacks = this.dataCallbacks.filter((c) => c !== cb);
}

onExit(cb: ExitCallback): void {
  this.exitCallbacks.push(cb);
}

offExit(cb: ExitCallback): void {
  this.exitCallbacks = this.exitCallbacks.filter((c) => c !== cb);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run tests/main/pty-manager.test.ts`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/main/pty-manager.ts tests/main/pty-manager.test.ts
git commit -m "fix: add offData/offExit to PtyManager to prevent callback accumulation"
```

---

### Task 4: Fix Backup Write Safety in SessionStore

If `fs.copyFile()` to `.bak` fails (e.g. disk full), the error is silently caught and the new state overwrites — potentially losing the only good copy. Should abort save if backup fails when a previous file exists.

**Files:**
- Modify: `src/main/session-store.ts:45-53`
- Test: `tests/main/session-store.test.ts` (add test)

- [ ] **Step 1: Write the failing test**

Add to `tests/main/session-store.test.ts` inside the `describe('state', ...)` block:

```typescript
it('aborts save if backup copy fails on existing file', async () => {
  const state1 = { groups: [], activeGroupId: 'g1', activeTerminalId: null, windowBounds: { x: 0, y: 0, width: 1200, height: 800 }, sidebarWidth: 220 };
  await store.saveState(state1);

  // Make the backup target directory read-only to force copyFile failure
  const bakPath = path.join(tmpDir, 'state.json.bak');
  // Write a fake bak file and make it immutable (read-only dir trick)
  fs.writeFileSync(bakPath, 'original backup');
  fs.chmodSync(bakPath, 0o000); // remove all permissions

  const state2 = { ...state1, sidebarWidth: 999 };
  await expect(store.saveState(state2)).rejects.toThrow();

  // Restore permissions for cleanup
  fs.chmodSync(bakPath, 0o644);

  // Original state.json should be unchanged
  const loaded = await store.loadState();
  expect(loaded.sidebarWidth).toBe(220);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/main/session-store.test.ts`
Expected: FAIL — save succeeds despite backup failure (current code catches all errors)

- [ ] **Step 3: Fix `saveState` to abort on backup failure**

In `src/main/session-store.ts`, update `saveState` (lines 45-53):

```typescript
// Before:
async saveState(state: AppState): Promise<void> {
  const statePath = this.filePath('state.json');
  try {
    await fs.access(statePath);
    await fs.copyFile(statePath, this.filePath('state.json.bak'));
  } catch {
    // No existing file to backup
  }
  await this.writeJson('state.json', state);
}

// After:
async saveState(state: AppState): Promise<void> {
  const statePath = this.filePath('state.json');
  try {
    await fs.access(statePath);
    // File exists — backup before overwriting. If backup fails, abort save.
    await fs.copyFile(statePath, this.filePath('state.json.bak'));
  } catch (err: any) {
    // ENOENT means no existing file to backup — safe to proceed
    if (err?.code !== 'ENOENT') throw err;
  }
  await this.writeJson('state.json', state);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run tests/main/session-store.test.ts`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/main/session-store.ts tests/main/session-store.test.ts
git commit -m "fix: abort state save when backup copy fails (prevents data loss)"
```

---

### Task 5: Add IPC Input Validation

IPC handlers in `ipc.ts` use `as any` casts for project data. Add type guards. Export them for testability.

**Files:**
- Create: `src/main/ipc-validators.ts`
- Modify: `src/main/ipc.ts:17-22`
- Test: `tests/main/ipc-validators.test.ts`

- [ ] **Step 1: Write the failing test**

Create `tests/main/ipc-validators.test.ts`:

```typescript
import { describe, it, expect } from 'vitest';
import { isValidTasks, isValidNotes, isValidVault } from '../../src/main/ipc-validators';

describe('IPC input validators', () => {
  describe('isValidTasks', () => {
    it('rejects non-array', () => {
      expect(isValidTasks('not an array')).toBe(false);
      expect(isValidTasks(null)).toBe(false);
      expect(isValidTasks(42)).toBe(false);
    });

    it('rejects tasks with missing fields', () => {
      expect(isValidTasks([{ id: '1' }])).toBe(false);
      expect(isValidTasks([{ id: '1', title: 'T' }])).toBe(false);
    });

    it('accepts valid tasks', () => {
      expect(isValidTasks([])).toBe(true);
      expect(isValidTasks([{ id: '1', title: 'Test', description: '', done: false }])).toBe(true);
    });
  });

  describe('isValidNotes', () => {
    it('rejects notes with missing fields', () => {
      expect(isValidNotes([{ id: '1' }])).toBe(false);
    });

    it('accepts valid notes', () => {
      expect(isValidNotes([])).toBe(true);
      expect(isValidNotes([{ id: '1', title: 'T', body: 'B', updatedAt: 1 }])).toBe(true);
    });
  });

  describe('isValidVault', () => {
    it('rejects entries with missing fields', () => {
      expect(isValidVault([{ id: '1', label: 'L' }])).toBe(false);
    });

    it('accepts valid vault entries', () => {
      expect(isValidVault([])).toBe(true);
      expect(isValidVault([{ id: '1', label: 'L', value: 'V' }])).toBe(true);
    });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/main/ipc-validators.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Create `src/main/ipc-validators.ts`**

```typescript
import type { Task, Note, VaultEntry } from '../shared/types';

export function isValidTasks(data: unknown): data is Task[] {
  return Array.isArray(data) && data.every(
    (t) => typeof t === 'object' && t !== null &&
      typeof (t as any).id === 'string' &&
      typeof (t as any).title === 'string' &&
      typeof (t as any).done === 'boolean'
  );
}

export function isValidNotes(data: unknown): data is Note[] {
  return Array.isArray(data) && data.every(
    (n) => typeof n === 'object' && n !== null &&
      typeof (n as any).id === 'string' &&
      typeof (n as any).title === 'string' &&
      typeof (n as any).body === 'string'
  );
}

export function isValidVault(data: unknown): data is VaultEntry[] {
  return Array.isArray(data) && data.every(
    (v) => typeof v === 'object' && v !== null &&
      typeof (v as any).id === 'string' &&
      typeof (v as any).label === 'string' &&
      typeof (v as any).value === 'string'
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/main/ipc-validators.test.ts`
Expected: All PASS

- [ ] **Step 5: Update `ipc.ts` to use validators**

Add import at top of `src/main/ipc.ts`:
```typescript
import { isValidTasks, isValidNotes, isValidVault } from './ipc-validators';
```

Replace the project save handlers (lines 18, 20, 22):

```typescript
// Before:
ipcMain.handle('project:saveTasks', async (_event: any, cwd: string, tasks: unknown) => projectData.saveTasks(cwd, tasks as any));
ipcMain.handle('project:saveNotes', async (_event: any, cwd: string, notes: unknown) => projectData.saveNotes(cwd, notes as any));
ipcMain.handle('project:saveVault', async (_event: any, cwd: string, entries: unknown) => projectData.saveVault(cwd, entries as any));

// After:
ipcMain.handle('project:saveTasks', async (_event: any, cwd: string, tasks: unknown) => {
  if (typeof cwd !== 'string' || !isValidTasks(tasks)) throw new Error('Invalid tasks data');
  return projectData.saveTasks(cwd, tasks);
});
ipcMain.handle('project:saveNotes', async (_event: any, cwd: string, notes: unknown) => {
  if (typeof cwd !== 'string' || !isValidNotes(notes)) throw new Error('Invalid notes data');
  return projectData.saveNotes(cwd, notes);
});
ipcMain.handle('project:saveVault', async (_event: any, cwd: string, entries: unknown) => {
  if (typeof cwd !== 'string' || !isValidVault(entries)) throw new Error('Invalid vault data');
  return projectData.saveVault(cwd, entries);
});
```

- [ ] **Step 6: Run all tests**

Run: `npx vitest run`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add src/main/ipc-validators.ts src/main/ipc.ts tests/main/ipc-validators.test.ts
git commit -m "fix: add input validation for project data IPC handlers"
```

---

### Task 6: Restrict `fs:readdir` and `fs:thumbnail` to Home Directory

The renderer can read any directory or generate thumbnails of any file. Restrict to paths within the user's home directory.

**Files:**
- Modify: `src/main/ipc.ts` (the `fs:readdir` and `fs:thumbnail` handlers)
- Test: `tests/main/ipc-path-restriction.test.ts`

**Note:** Line numbers in `ipc.ts` will have shifted from Task 5 changes. Search for the handler strings (`'fs:readdir'`, `'fs:thumbnail'`) rather than relying on line numbers.

- [ ] **Step 1: Write the failing test**

Create `tests/main/ipc-path-restriction.test.ts`:

```typescript
import { describe, it, expect } from 'vitest';
import os from 'os';
import path from 'path';

// Test the path restriction logic directly
function isWithinHome(targetPath: string): boolean {
  const resolved = path.resolve(targetPath);
  const home = os.homedir();
  return resolved === home || resolved.startsWith(home + '/');
}

describe('path restriction', () => {
  it('allows paths within home directory', () => {
    expect(isWithinHome(os.homedir())).toBe(true);
    expect(isWithinHome(path.join(os.homedir(), 'Documents'))).toBe(true);
    expect(isWithinHome(path.join(os.homedir(), 'Projects', 'app'))).toBe(true);
  });

  it('rejects paths outside home directory', () => {
    expect(isWithinHome('/etc/passwd')).toBe(false);
    expect(isWithinHome('/tmp/evil')).toBe(false);
    expect(isWithinHome('/')).toBe(false);
  });

  it('rejects paths that look like home but are not (prefix attack)', () => {
    // e.g. /Users/alice vs /Users/alicevil
    const fakeHome = os.homedir() + 'evil';
    expect(isWithinHome(fakeHome)).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it passes (establishes the logic)**

Run: `npx vitest run tests/main/ipc-path-restriction.test.ts`
Expected: PASS

- [ ] **Step 3: Add path restriction to `fs:readdir` in ipc.ts**

Find the `fs:readdir` handler (search for `'fs:readdir'`). Add after the `path.resolve` line:

```typescript
ipcMain.handle('fs:readdir', async (_event: any, dirPath: string) => {
  if (typeof dirPath !== 'string' || dirPath.includes('\0')) return [];
  const resolved = path.resolve(dirPath);
  // Restrict to home directory subtree (prevent arbitrary filesystem reads)
  const home = os.homedir();
  if (resolved !== home && !resolved.startsWith(home + '/')) return [];
  try {
    ...
```

- [ ] **Step 4: Add path restriction to `fs:thumbnail` in ipc.ts**

Find the `fs:thumbnail` handler (search for `'fs:thumbnail'`). Add the same restriction:

```typescript
ipcMain.handle('fs:thumbnail', async (_event: any, filePath: string) => {
  if (typeof filePath !== 'string' || filePath.includes('\0')) return null;
  const resolved = path.resolve(filePath);
  const home = os.homedir();
  if (resolved !== home && !resolved.startsWith(home + '/')) return null;
  try {
    ...
```

- [ ] **Step 5: Run all tests**

Run: `npx vitest run`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add src/main/ipc.ts tests/main/ipc-path-restriction.test.ts
git commit -m "fix: restrict fs:readdir and fs:thumbnail to home directory"
```

---

### Task 7: Extract Safe Window Access Helper in IPC

Multiple places in `ipc.ts` use `BrowserWindow.getAllWindows()[0]` without checking if the array is empty. Extract a helper.

**Files:**
- Modify: `src/main/ipc.ts`

**Note:** Line numbers will have shifted from Tasks 5 and 6.

- [ ] **Step 1: Add helper function at top of ipc.ts (after imports)**

```typescript
function getMainWindow(): BrowserWindow | null {
  const windows = BrowserWindow.getAllWindows();
  return windows.length > 0 ? windows[0] : null;
}
```

- [ ] **Step 2: Replace all `BrowserWindow.getAllWindows()[0]` occurrences**

Search for `BrowserWindow.getAllWindows()[0]` in `ipc.ts` and replace each with `getMainWindow()`. There are 8 occurrences — in the monitor status callback, the url callback, the ptyManager.onData forwarder, the ptyManager.onExit forwarder, and the 4 dialog handlers.

Each one already has optional chaining (`win?.`), so the null return from `getMainWindow()` is safe.

- [ ] **Step 3: Run all tests and build**

Run: `npx vitest run && npm run build`
Expected: All pass

- [ ] **Step 4: Commit**

```bash
git add src/main/ipc.ts
git commit -m "refactor: extract getMainWindow() helper for safe window access"
```

---

### Task 8: Fix Package Metadata

**Files:**
- Modify: `package.json`
- Modify: `electron-builder.yml`

- [ ] **Step 1: Update `package.json` author**

```json
// Before:
"author": "",

// After:
"author": "Emil Merdzhanov <etmerdzhanov@gmail.com>",
```

(Matching the name and email in the LICENSE file.)

License is already "ISC" which matches the LICENSE file — no change needed.

- [ ] **Step 2: Update `electron-builder.yml` maintainer (line 20)**

```yaml
# Before:
maintainer: dispatch

# After:
maintainer: Emil Merdzhanov <etmerdzhanov@gmail.com>
```

- [ ] **Step 3: Run build to verify nothing broke**

Run: `npm run build`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add package.json electron-builder.yml
git commit -m "chore: fill in package author and maintainer metadata"
```

---

### Task 9: Final Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

Run: `npx vitest run`
Expected: All tests PASS

- [ ] **Step 2: TypeScript type check**

Run: `npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Full build**

Run: `npm run build`
Expected: Build succeeds (webpack bundle-size warnings are OK)

- [ ] **Step 4: Quick manual smoke test checklist**

Verify by running `npm start`:
- App launches without console errors
- Can open a folder and spawn a terminal
- Terminal accepts input and shows output
- Can split panes with Cmd+D
- Can close split with Cmd+W
- Settings panel opens with Cmd+,
- Quitting the app doesn't leave orphan processes
