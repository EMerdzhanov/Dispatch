# Built-in Browser Panel — Design Spec

An embedded Chromium browser inside Dispatch that auto-detects localhost URLs from terminal output, shows your running app alongside the terminal, and captures console logs/errors.

## Browser Sub-Tabs

Each project tab can have sub-tabs: the default terminal view and zero or more browser tabs.

```
[⌂ Dispatch ②]  [+ ]                    ⚙
──────────────────────────────────────────────
[Terminals]  [🌐 localhost:5002]  [🌐 localhost:3000]
```

- **Terminals** sub-tab — the current view (sidebar + terminal area), always present
- **Browser sub-tabs** — each renders an embedded Chromium browser for a URL
- Clicking a browser sub-tab switches the main area from terminal view to browser view
- Clicking "Terminals" switches back; terminals keep running in the background
- Multiple browser tabs per project allowed (e.g. frontend on :3000, API on :8080)
- The sidebar remains visible in browser view — terminals, tasks, notes, vault all accessible

## Auto-Detection

When terminal output contains a localhost URL, Dispatch auto-creates a browser sub-tab.

### Detection

The `TerminalMonitor` (already watching PTY output in the main process) gets a new regex:

```
https?://(?:localhost|127\.0\.0\.1):(\d{3,5})
```

Also matches common framework patterns:
- `Local: http://localhost:3000`
- `ready on http://localhost:5002`
- `Server running at http://127.0.0.1:8080`

### Behavior

- On URL detection → emit IPC event `browser:detected` with URL and terminal ID
- Renderer creates a browser sub-tab and shows toast: "App detected on localhost:5002"
- **Deduplication:** if a sub-tab for that port already exists, refresh it instead of creating a new one
- **Debounce:** 2 seconds after first detection before creating the tab (dev servers print URLs multiple times during startup)

## Browser View

When a browser sub-tab is active, the main area shows:

### Top Bar (32px)

- Back / Forward / Refresh buttons (icon-style)
- Editable URL input field (user can type a URL and press Enter)
- Close button (✕) to remove this browser tab

### Browser Area

- Electron `<webview>` tag rendering the page
- Full remaining vertical space above the console panel
- Supports standard web features (CSS, JS, images, websockets)

### Console Panel (collapsible, bottom ~30%)

- Toggle button: "Console (3)" showing unread message count
- When expanded: scrollable list of console messages with timestamps
- Each message: timestamp, level icon (ℹ info / ⚠ warn / ✕ error), message text
- Errors in red, warnings in yellow, info in default text color
- "Clear" button to clear the log
- "Pipe to Terminal" toggle — when enabled, console errors appear in a "Browser Log" terminal

### Console Capture

```typescript
// The <webview> element exposes console events:
webview.addEventListener('console-message', (e) => {
  // e.level: 1=info, 2=warn, 3=error (note: webview uses different numbering than webContents)
  // e.message: string
  // e.line: number
  // e.sourceId: string
});
```

Messages stored in a rolling buffer (last 500) in the Zustand store, per browser tab.

### Pipe to Terminal

When "Pipe to Terminal" is enabled:
- Creates a special terminal entry in the sidebar called "Browser Log"
- This is a read-only pseudo-terminal (no PTY backing — just receives text)
- Console errors are formatted and appended: `[ERROR] message (source:line)`
- Claude Code in another terminal can reference these errors

## Data Types

```typescript
interface BrowserTab {
  id: string;
  url: string;
  title?: string;
}

interface ConsoleMessage {
  timestamp: number;
  level: 'info' | 'warn' | 'error';
  message: string;
  source?: string;
  line?: number;
}
```

## Electron Configuration

```typescript
// In main/index.ts, BrowserWindow webPreferences:
webviewTag: true
```

The `<webview>` tag is used instead of `BrowserView` because it's a DOM element that integrates naturally with React. It supports `src`, event listeners, and `executeJavaScript`.

## New Files

| File | Purpose |
|---|---|
| `src/renderer/components/BrowserPanel.tsx` | URL bar + webview + console panel |
| `src/renderer/components/BrowserConsole.tsx` | Collapsible console log viewer |
| `src/renderer/components/SubTabBar.tsx` | Sub-tab bar (Terminals / browser tabs) |

## Modified Files

| File | Changes |
|---|---|
| `src/shared/types.ts` | `BrowserTab`, `ConsoleMessage` interfaces; add `browserTabs` to `ProjectGroup` |
| `src/renderer/store/types.ts` | Browser state fields + actions |
| `src/renderer/store/index.ts` | Browser tab management actions |
| `src/main/terminal-monitor.ts` | Add localhost URL detection + `browser:detected` event |
| `src/main/ipc.ts` | Forward `browser:detected` events |
| `src/main/preload.ts` | Expose browser events |
| `src/main/index.ts` | Enable `webviewTag: true` in webPreferences |
| `src/renderer/App.tsx` | Listen for `browser:detected`, create tabs, show toast |
| `src/renderer/components/TerminalArea.tsx` | Switch between terminal and browser view based on active sub-tab |
| `src/renderer/styles/dispatch.css` | Browser panel, console, sub-tab bar classes |

## IPC Channels

| Channel | Direction | Purpose |
|---|---|---|
| `browser:detected` | main → renderer | Localhost URL detected in terminal output |

## Store State

Follows the same pattern as terminals: `ProjectGroup` holds an ID list, the store holds metadata.

```typescript
// Add to ProjectGroup (in shared/types.ts):
browserTabIds: string[];   // list of browser tab IDs in this group

// Add to StoreState:
browserTabs: Record<string, BrowserTab>;   // all browser tabs by ID (mirrors terminals pattern)
activeBrowserTabId: string | null;          // null = showing terminals view
consoleMessages: Record<string, ConsoleMessage[]>;  // keyed by browser tab ID
pipeToTerminal: boolean;

// Add to StoreActions:
addBrowserTab: (groupId: string, tab: BrowserTab) => void;
removeBrowserTab: (groupId: string, tabId: string) => void;
setActiveBrowserTab: (tabId: string | null) => void;  // null = back to terminals
addConsoleMessage: (tabId: string, message: ConsoleMessage) => void;
clearConsoleMessages: (tabId: string) => void;
togglePipeToTerminal: () => void;
```

## Out of Scope

- No bookmark system
- No tab dragging/reordering
- No multi-window browser
- No cookie/storage management
- No browser extensions
- No mobile viewport emulation
- No screenshot/recording
