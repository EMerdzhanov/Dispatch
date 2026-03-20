# Built-in Browser Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an embedded Chromium browser as project sub-tabs that auto-detects localhost URLs from terminal output and captures console logs.

**Architecture:** The `<webview>` tag renders web pages inside the Electron renderer. A `SubTabBar` switches between terminal view and browser tabs. The `TerminalMonitor` detects localhost URLs and emits events. Console messages are captured via webview events and displayed in a collapsible panel.

**Tech Stack:** Electron `<webview>` tag, existing React + Zustand + CSS design system. No new dependencies.

---

## File Structure

```
src/
├── shared/
│   └── types.ts                      # BrowserTab, ConsoleMessage, browserTabIds on ProjectGroup
├── main/
│   ├── terminal-monitor.ts           # Add localhost URL detection
│   ├── ipc.ts                        # Forward browser:detected events
│   ├── preload.ts                    # Expose browser events
│   └── index.ts                      # Enable webviewTag
├── renderer/
│   ├── store/
│   │   ├── types.ts                  # Browser state + actions
│   │   └── index.ts                  # Browser action implementations
│   ├── components/
│   │   ├── SubTabBar.tsx             # NEW: Terminals / browser sub-tabs
│   │   ├── BrowserPanel.tsx          # NEW: URL bar + webview
│   │   ├── BrowserConsole.tsx        # NEW: Console log viewer
│   │   ├── TerminalArea.tsx          # Switch between terminal and browser view
│   │   └── App.tsx                   # Listen for browser:detected, create tabs
│   └── styles/
│       └── dispatch.css              # Browser panel classes
```

---

### Task 1: Types + Store + Electron Config

**Files:**
- Modify: `src/shared/types.ts`
- Modify: `src/renderer/store/types.ts`
- Modify: `src/renderer/store/index.ts`
- Modify: `src/main/index.ts`

- [ ] **Step 1: Add types to shared/types.ts**

```typescript
// Add after VaultEntry interface:

export interface BrowserTab {
  id: string;
  url: string;
  title?: string;
}

export interface ConsoleMessage {
  timestamp: number;
  level: 'info' | 'warn' | 'error';
  message: string;
  source?: string;
  line?: number;
}
```

Add `browserTabIds` to `ProjectGroup`:
```typescript
interface ProjectGroup {
  // ... existing fields ...
  browserTabIds: string[];
}
```

- [ ] **Step 2: Update store types**

In `src/renderer/store/types.ts`, add imports for `BrowserTab`, `ConsoleMessage`.

Add to `StoreState`:
```typescript
browserTabs: Record<string, BrowserTab>;
activeBrowserTabId: string | null;
consoleMessages: Record<string, ConsoleMessage[]>;
pipeToTerminal: boolean;
```

Add to `StoreActions`:
```typescript
addBrowserTab: (groupId: string, tab: BrowserTab) => void;
removeBrowserTab: (groupId: string, tabId: string) => void;
setActiveBrowserTab: (tabId: string | null) => void;
addConsoleMessage: (tabId: string, message: ConsoleMessage) => void;
clearConsoleMessages: (tabId: string) => void;
togglePipeToTerminal: () => void;
```

- [ ] **Step 3: Implement store actions**

In `src/renderer/store/index.ts`, add initial state:
```typescript
browserTabs: {},
activeBrowserTabId: null,
consoleMessages: {},
pipeToTerminal: false,
```

Add `browserTabIds: []` to the `addGroup` action where new groups are created.

Add actions:
```typescript
addBrowserTab: (groupId, tab) => set((s) => ({
  browserTabs: { ...s.browserTabs, [tab.id]: tab },
  groups: s.groups.map((g) => g.id === groupId
    ? { ...g, browserTabIds: [...(g.browserTabIds || []), tab.id] }
    : g),
  activeBrowserTabId: tab.id,
})),

removeBrowserTab: (groupId, tabId) => set((s) => ({
  browserTabs: Object.fromEntries(Object.entries(s.browserTabs).filter(([k]) => k !== tabId)),
  groups: s.groups.map((g) => g.id === groupId
    ? { ...g, browserTabIds: (g.browserTabIds || []).filter((id) => id !== tabId) }
    : g),
  activeBrowserTabId: s.activeBrowserTabId === tabId ? null : s.activeBrowserTabId,
  consoleMessages: Object.fromEntries(Object.entries(s.consoleMessages).filter(([k]) => k !== tabId)),
})),

setActiveBrowserTab: (tabId) => set({ activeBrowserTabId: tabId }),

addConsoleMessage: (tabId, message) => set((s) => {
  const existing = s.consoleMessages[tabId] || [];
  const updated = [...existing, message].slice(-500); // rolling buffer
  return { consoleMessages: { ...s.consoleMessages, [tabId]: updated } };
}),

clearConsoleMessages: (tabId) => set((s) => ({
  consoleMessages: { ...s.consoleMessages, [tabId]: [] },
})),

togglePipeToTerminal: () => set((s) => ({ pipeToTerminal: !s.pipeToTerminal })),
```

- [ ] **Step 4: Enable webviewTag in Electron**

In `src/main/index.ts`, add to the `webPreferences` object in `createWindow()`:
```typescript
webviewTag: true,
```

- [ ] **Step 5: Build and test**

```bash
npm run build && npx vitest run
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add browser tab types, store state, and enable webviewTag"
```

---

### Task 2: URL Detection in TerminalMonitor

**Files:**
- Modify: `src/main/terminal-monitor.ts`
- Modify: `tests/main/terminal-monitor.test.ts`
- Modify: `src/main/ipc.ts`
- Modify: `src/main/preload.ts`

- [ ] **Step 1: Add URL detection tests**

Add to `tests/main/terminal-monitor.test.ts`:

```typescript
it('detects localhost URLs', async () => {
  const urlCallback = vi.fn();
  monitor = new TerminalMonitor(statusCallback, urlCallback);
  monitor.onData('t1', 'Server running at http://localhost:3000');
  await new Promise((r) => setTimeout(r, 2500)); // 2s debounce
  expect(urlCallback).toHaveBeenCalledWith('t1', 'http://localhost:3000');
});

it('detects 127.0.0.1 URLs', async () => {
  const urlCallback = vi.fn();
  monitor = new TerminalMonitor(statusCallback, urlCallback);
  monitor.onData('t1', 'Local: http://127.0.0.1:5002');
  await new Promise((r) => setTimeout(r, 2500));
  expect(urlCallback).toHaveBeenCalledWith('t1', 'http://127.0.0.1:5002');
});

it('deduplicates same port detections', async () => {
  const urlCallback = vi.fn();
  monitor = new TerminalMonitor(statusCallback, urlCallback);
  monitor.onData('t1', 'http://localhost:3000');
  monitor.onData('t1', 'http://localhost:3000'); // duplicate
  await new Promise((r) => setTimeout(r, 2500));
  expect(urlCallback).toHaveBeenCalledTimes(1);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx vitest run tests/main/terminal-monitor.test.ts`
Expected: FAIL — TerminalMonitor constructor doesn't accept second argument

- [ ] **Step 3: Update TerminalMonitor to detect URLs**

In `src/main/terminal-monitor.ts`:

Add a second callback type and URL detection:

```typescript
type UrlCallback = (terminalId: string, url: string) => void;

const URL_REGEX = /https?:\/\/(?:localhost|127\.0\.0\.1):(\d{3,5})/g;
const URL_DEBOUNCE_MS = 2000;
```

Update constructor:
```typescript
constructor(callback: StatusCallback, private urlCallback?: UrlCallback) {
```

Add URL tracking fields:
```typescript
private detectedPorts = new Set<string>(); // "terminalId:port"
private urlDebounceTimers = new Map<string, NodeJS.Timeout>();
```

In `onData`, after existing pattern matching, add URL detection:
```typescript
// Detect localhost URLs
const clean = stripAnsi(data);
const urlMatches = clean.matchAll(URL_REGEX);
for (const match of urlMatches) {
  const url = match[0];
  const port = match[1];
  const key = `${terminalId}:${port}`;

  if (this.detectedPorts.has(key)) continue; // already detected

  // Debounce: wait 2s before emitting (dev servers print URL multiple times)
  const existing = this.urlDebounceTimers.get(key);
  if (existing) continue; // already waiting

  this.urlDebounceTimers.set(key, setTimeout(() => {
    this.detectedPorts.add(key);
    this.urlCallback?.(terminalId, url);
    this.urlDebounceTimers.delete(key);
  }, URL_DEBOUNCE_MS));
}
```

In `cleanup`, clear URL timers:
```typescript
// Clear URL timers for this terminal
for (const [key, timer] of this.urlDebounceTimers) {
  if (key.startsWith(terminalId + ':')) {
    clearTimeout(timer);
    this.urlDebounceTimers.delete(key);
  }
}
for (const key of this.detectedPorts) {
  if (key.startsWith(terminalId + ':')) {
    this.detectedPorts.delete(key);
  }
}
```

- [ ] **Step 4: Update existing TerminalMonitor instantiation in ipc.ts**

The existing instantiation passes one callback. Add the URL callback:

```typescript
const monitor = new TerminalMonitor(
  // status callback (existing)
  (terminalId, status) => {
    // ... existing code ...
  },
  // URL callback (new)
  (terminalId, url) => {
    const win = BrowserWindow.getAllWindows()[0];
    win?.webContents.send('browser:detected', terminalId, url);
  }
);
```

- [ ] **Step 5: Add to preload**

In `src/main/preload.ts`:
```typescript
browser: {
  onDetected: (cb: (terminalId: string, url: string) => void) => {
    ipcRenderer.on('browser:detected', (_event, terminalId, url) => cb(terminalId, url));
  },
},
```

- [ ] **Step 6: Run tests**

Run: `npx vitest run`
Expected: All tests pass (existing + 3 new URL detection tests)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add localhost URL detection in terminal monitor"
```

---

### Task 3: CSS + SubTabBar Component

**Files:**
- Modify: `src/renderer/styles/dispatch.css`
- Create: `src/renderer/components/SubTabBar.tsx`

- [ ] **Step 1: Add CSS classes**

Add to `dispatch.css` before the `@keyframes` section:

```css
/* SUB-TAB BAR */
.d-subtabs {
  display: flex;
  align-items: center;
  gap: 1px;
  padding: 0 var(--space-2);
  background: var(--bg-secondary);
  border-bottom: 1px solid var(--border-default);
  flex-shrink: 0;
  height: 28px;
  overflow-x: auto;
}
.d-subtabs::-webkit-scrollbar { display: none; }

.d-subtab {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 0 var(--space-3);
  height: 22px;
  font-size: 10px;
  border-radius: var(--radius-sm);
  color: var(--text-dim);
  transition: color 0.15s, background 0.15s;
  flex-shrink: 0;
  white-space: nowrap;
}
.d-subtab:hover { color: var(--text-muted); background: var(--bg-tertiary); }
.d-subtab--active { color: var(--text-primary); background: var(--bg-tertiary); }

.d-subtab__close {
  font-size: 8px;
  color: var(--text-dim);
  margin-left: 2px;
  opacity: 0;
  transition: opacity 0.1s;
}
.d-subtab:hover .d-subtab__close { opacity: 1; }
.d-subtab__close:hover { color: var(--accent-primary); }

/* BROWSER PANEL */
.d-browser {
  display: flex;
  flex-direction: column;
  flex: 1 1 0%;
  min-height: 0;
}

.d-browser__toolbar {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: 0 var(--space-3);
  height: var(--terminal-header-height);
  flex-shrink: 0;
  background: var(--bg-tertiary);
  border-bottom: 1px solid var(--border-default);
}

.d-browser__nav-btn {
  font-size: 12px;
  color: var(--text-dim);
  padding: 2px 4px;
  border-radius: var(--radius-sm);
  transition: color 0.1s, background 0.1s;
}
.d-browser__nav-btn:hover { color: var(--text-muted); background: var(--bg-elevated); }
.d-browser__nav-btn:disabled { opacity: 0.3; cursor: default; }

.d-browser__url {
  flex: 1;
  padding: 3px 8px;
  font-size: var(--font-size-sm);
  background: var(--bg-primary);
  color: var(--text-primary);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
}
.d-browser__url:focus { border-color: var(--border-default); }

.d-browser__webview {
  flex: 1 1 0%;
  min-height: 0;
  border: none;
}

/* BROWSER CONSOLE */
.d-console {
  flex-shrink: 0;
  border-top: 1px solid var(--border-default);
  background: var(--bg-secondary);
}

.d-console__toggle {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 4px var(--space-3);
  font-size: 10px;
  color: var(--text-dim);
  transition: background 0.1s;
}
.d-console__toggle:hover { background: var(--bg-tertiary); }

.d-console__badge {
  font-size: 9px;
  padding: 0 5px;
  border-radius: 10px;
  background: var(--accent-primary);
  color: #fff;
  margin-left: 4px;
  line-height: 14px;
}

.d-console__list {
  max-height: 200px;
  overflow-y: auto;
  border-top: 1px solid var(--border-subtle);
}

.d-console__item {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  padding: 3px var(--space-3);
  font-size: var(--font-size-xs);
  border-bottom: 1px solid var(--border-subtle);
}

.d-console__item--error { color: var(--accent-primary); }
.d-console__item--warn { color: var(--accent-yellow); }
.d-console__item--info { color: var(--text-dim); }

.d-console__time { color: var(--text-dim); flex-shrink: 0; font-size: 8px; margin-top: 1px; }
.d-console__level { flex-shrink: 0; font-size: 8px; margin-top: 1px; }
.d-console__msg { word-break: break-word; flex: 1; }

.d-console__actions {
  display: flex;
  gap: var(--space-2);
  padding: 4px var(--space-3);
  border-top: 1px solid var(--border-subtle);
}

.d-console__action {
  font-size: 9px;
  color: var(--text-dim);
  transition: color 0.1s;
}
.d-console__action:hover { color: var(--text-muted); }
.d-console__action--active { color: var(--accent-green); }
```

- [ ] **Step 2: Create SubTabBar**

```typescript
// src/renderer/components/SubTabBar.tsx
import React from 'react';
import { useStore } from '../store';

export function SubTabBar() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const browserTabs = useStore((s) => s.browserTabs);
  const activeBrowserTabId = useStore((s) => s.activeBrowserTabId);
  const setActiveBrowserTab = useStore((s) => s.setActiveBrowserTab);
  const removeBrowserTab = useStore((s) => s.removeBrowserTab);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const groupBrowserTabs = (activeGroup?.browserTabIds || [])
    .map((id) => browserTabs[id])
    .filter(Boolean);

  // Don't show sub-tab bar if no browser tabs
  if (groupBrowserTabs.length === 0) return null;

  return (
    <div className="d-subtabs">
      <button
        className={`d-subtab${activeBrowserTabId === null ? ' d-subtab--active' : ''}`}
        onClick={() => setActiveBrowserTab(null)}
      >
        Terminals
      </button>
      {groupBrowserTabs.map((tab) => (
        <button
          key={tab.id}
          className={`d-subtab${activeBrowserTabId === tab.id ? ' d-subtab--active' : ''}`}
          onClick={() => setActiveBrowserTab(tab.id)}
        >
          🌐 {tab.title || new URL(tab.url).host}
          <span
            className="d-subtab__close"
            onClick={(e) => {
              e.stopPropagation();
              if (activeGroupId) removeBrowserTab(activeGroupId, tab.id);
            }}
          >
            ✕
          </span>
        </button>
      ))}
    </div>
  );
}
```

- [ ] **Step 3: Build and commit**

```bash
npm run build
git add -A
git commit -m "feat: add CSS classes and SubTabBar for browser panel"
```

---

### Task 4: BrowserConsole + BrowserPanel

**Files:**
- Create: `src/renderer/components/BrowserConsole.tsx`
- Create: `src/renderer/components/BrowserPanel.tsx`

- [ ] **Step 1: Create BrowserConsole**

```typescript
// src/renderer/components/BrowserConsole.tsx
import React, { useState } from 'react';
import { useStore } from '../store';

interface BrowserConsoleProps {
  tabId: string;
}

export function BrowserConsole({ tabId }: BrowserConsoleProps) {
  const messages = useStore((s) => s.consoleMessages[tabId]) || [];
  const clearMessages = useStore((s) => s.clearConsoleMessages);
  const pipeToTerminal = useStore((s) => s.pipeToTerminal);
  const togglePipe = useStore((s) => s.togglePipeToTerminal);
  const [expanded, setExpanded] = useState(false);

  const errorCount = messages.filter((m) => m.level === 'error').length;
  const totalCount = messages.length;

  const levelIcons = { info: 'ℹ', warn: '⚠', error: '✕' };

  return (
    <div className="d-console">
      <button className="d-console__toggle" onClick={() => setExpanded(!expanded)}>
        <span>
          Console {totalCount > 0 && <span className="d-console__badge">{totalCount}</span>}
          {errorCount > 0 && <span style={{ color: 'var(--accent-primary)', marginLeft: 4, fontSize: 9 }}>{errorCount} errors</span>}
        </span>
        <span>{expanded ? '▼' : '▲'}</span>
      </button>

      {expanded && (
        <>
          <div className="d-console__list">
            {messages.length === 0 && (
              <div className="d-console__item d-console__item--info">
                <span className="d-console__msg">No console messages yet</span>
              </div>
            )}
            {messages.map((msg, i) => (
              <div key={i} className={`d-console__item d-console__item--${msg.level}`}>
                <span className="d-console__time">
                  {new Date(msg.timestamp).toLocaleTimeString()}
                </span>
                <span className="d-console__level">{levelIcons[msg.level]}</span>
                <span className="d-console__msg">{msg.message}</span>
              </div>
            ))}
          </div>
          <div className="d-console__actions">
            <button className="d-console__action" onClick={() => clearMessages(tabId)}>Clear</button>
            <button
              className={`d-console__action${pipeToTerminal ? ' d-console__action--active' : ''}`}
              onClick={togglePipe}
            >
              {pipeToTerminal ? '✓ Piping to Terminal' : 'Pipe to Terminal'}
            </button>
          </div>
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Create BrowserPanel**

```typescript
// src/renderer/components/BrowserPanel.tsx
import React, { useRef, useEffect, useState } from 'react';
import { useStore } from '../store';
import { BrowserConsole } from './BrowserConsole';

interface BrowserPanelProps {
  tabId: string;
}

export function BrowserPanel({ tabId }: BrowserPanelProps) {
  const tab = useStore((s) => s.browserTabs[tabId]);
  const addConsoleMessage = useStore((s) => s.addConsoleMessage);
  const webviewRef = useRef<any>(null);
  const [urlInput, setUrlInput] = useState(tab?.url || '');
  const [canGoBack, setCanGoBack] = useState(false);
  const [canGoForward, setCanGoForward] = useState(false);

  useEffect(() => {
    if (!tab) return;
    setUrlInput(tab.url);
  }, [tab?.url]);

  useEffect(() => {
    const webview = webviewRef.current;
    if (!webview) return;

    const handleConsole = (e: any) => {
      const levelMap: Record<number, 'info' | 'warn' | 'error'> = {
        0: 'info', // verbose/debug
        1: 'info',
        2: 'warn',
        3: 'error',
      };
      addConsoleMessage(tabId, {
        timestamp: Date.now(),
        level: levelMap[e.level] || 'info',
        message: e.message,
        source: e.sourceId,
        line: e.line,
      });
    };

    const handleNavigation = () => {
      setCanGoBack(webview.canGoBack());
      setCanGoForward(webview.canGoForward());
      setUrlInput(webview.getURL());
    };

    webview.addEventListener('console-message', handleConsole);
    webview.addEventListener('did-navigate', handleNavigation);
    webview.addEventListener('did-navigate-in-page', handleNavigation);

    return () => {
      webview.removeEventListener('console-message', handleConsole);
      webview.removeEventListener('did-navigate', handleNavigation);
      webview.removeEventListener('did-navigate-in-page', handleNavigation);
    };
  }, [tabId]);

  if (!tab) return null;

  const navigate = (url: string) => {
    let normalized = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      normalized = 'http://' + url;
    }
    if (webviewRef.current) {
      webviewRef.current.src = normalized;
    }
    setUrlInput(normalized);
  };

  return (
    <div className="d-browser">
      {/* Toolbar */}
      <div className="d-browser__toolbar">
        <button className="d-browser__nav-btn" disabled={!canGoBack}
          onClick={() => webviewRef.current?.goBack()}>◀</button>
        <button className="d-browser__nav-btn" disabled={!canGoForward}
          onClick={() => webviewRef.current?.goForward()}>▶</button>
        <button className="d-browser__nav-btn"
          onClick={() => webviewRef.current?.reload()}>↻</button>
        <input
          className="d-browser__url"
          value={urlInput}
          onChange={(e) => setUrlInput(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') navigate(urlInput); }}
        />
      </div>

      {/* Webview */}
      <webview
        ref={webviewRef}
        src={tab.url}
        className="d-browser__webview"
        style={{ flex: '1 1 0%', minHeight: 0 }}
      />

      {/* Console */}
      <BrowserConsole tabId={tabId} />
    </div>
  );
}
```

Note: TypeScript may not know about the `<webview>` tag. If needed, add at the top of the file:
```typescript
declare global {
  namespace JSX {
    interface IntrinsicElements {
      webview: React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement> & {
        src?: string;
        preload?: string;
        nodeintegration?: string;
      }, HTMLElement>;
    }
  }
}
```

- [ ] **Step 3: Build and commit**

```bash
npm run build
git add -A
git commit -m "feat: add BrowserPanel and BrowserConsole components"
```

---

### Task 5: Wire Everything Together

**Files:**
- Modify: `src/renderer/components/TerminalArea.tsx`
- Modify: `src/renderer/App.tsx`

- [ ] **Step 1: Update TerminalArea to switch between terminals and browser**

Read `src/renderer/components/TerminalArea.tsx`. Add imports for `SubTabBar` and `BrowserPanel`. Wrap the existing content:

```typescript
import { SubTabBar } from './SubTabBar';
import { BrowserPanel } from './BrowserPanel';

export function TerminalArea({ onSpawnInCwd }: TerminalAreaProps) {
  const activeBrowserTabId = useStore((s) => s.activeBrowserTabId);
  // ... existing selectors ...

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: '1 1 0%', minHeight: 0 }}>
      {/* Sub-tab bar — only shows when browser tabs exist */}
      <SubTabBar />

      {/* Browser view */}
      {activeBrowserTabId ? (
        <BrowserPanel tabId={activeBrowserTabId} />
      ) : (
        // Existing terminal rendering (the current content of TerminalArea)
        // Wrap in a div with flex: 1
        <div className="d-terminal-area">
          {/* ... existing terminal/split/empty rendering ... */}
        </div>
      )}
    </div>
  );
}
```

Keep ALL existing terminal rendering logic — just wrap it in a conditional. When `activeBrowserTabId` is null, show terminals. When it's set, show the browser.

- [ ] **Step 2: Listen for browser:detected in App.tsx**

Add a useEffect:

```typescript
useEffect(() => {
  (window as any).dispatch?.browser?.onDetected((terminalId: string, url: string) => {
    const state = useStore.getState();
    // Find which group this terminal belongs to
    const group = state.groups.find((g) => g.terminalIds.includes(terminalId));
    if (!group) return;

    // Check if a tab for this URL already exists in this group
    const existingTab = (group.browserTabIds || [])
      .map((id) => state.browserTabs[id])
      .find((t) => t && new URL(t.url).port === new URL(url).port);

    if (existingTab) return; // already have a tab for this port

    // Create new browser tab
    const tab = { id: crypto.randomUUID(), url, title: new URL(url).host };
    state.addBrowserTab(group.id, tab);
  });
}, []);
```

- [ ] **Step 3: Build and verify**

```bash
npm run build && npx vitest run
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: wire browser panel into TerminalArea with auto-detection"
```

---

### Task 6: Integration Testing

- [ ] **Step 1: Full build + test suite**

```bash
npm run build && npx vitest run
```

- [ ] **Step 2: Test auto-detection**

1. Open a folder, spawn a shell
2. Run a dev server: `python3 -m http.server 8080` or `npx serve .`
3. Terminal should output a localhost URL
4. After ~2 seconds, a browser sub-tab should appear: `🌐 localhost:8080`
5. Click it → embedded browser shows the page

- [ ] **Step 3: Test browser controls**

1. URL bar: type a different URL, press Enter → navigates
2. Back/Forward buttons work after navigating
3. Refresh button reloads the page
4. ✕ on the sub-tab closes the browser tab

- [ ] **Step 4: Test console capture**

1. Open a page that logs to console
2. Click "Console" toggle → see messages with timestamps and levels
3. Errors in red, warnings in yellow
4. "Clear" clears the list
5. "Pipe to Terminal" toggle

- [ ] **Step 5: Test sub-tab switching**

1. Click "Terminals" sub-tab → back to terminal view, terminals preserved
2. Click browser sub-tab → back to browser, page still loaded
3. Switch project tabs → browser tabs are per-project

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore: integration testing complete for browser panel"
```
