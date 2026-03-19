# Dispatch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a desktop terminal manager (Electron) that groups terminals by project, provides quick-launch presets for Claude Code, detects external terminals, and offers full keyboard + mouse navigation.

**Architecture:** Electron main process manages PTYs (node-pty), session persistence, and process scanning. React renderer handles UI with xterm.js terminals, Zustand state, and Tailwind styling. IPC bridge connects them via contextBridge.

**Tech Stack:** Electron, React 18, TypeScript, xterm.js, node-pty, Zustand, Tailwind CSS, fuse.js, electron-builder

---

## File Structure

```
src/
├── main/
│   ├── index.ts                    # Electron main process entry
│   ├── ipc.ts                      # IPC handler registration
│   ├── pty-manager.ts              # PTY lifecycle (spawn, data, resize, kill, exit)
│   ├── session-store.ts            # Read/write state.json, presets.json, settings.json
│   ├── process-scanner.ts          # External terminal detection
│   ├── tmux.ts                     # tmux session detection and attach
│   └── preload.ts                  # contextBridge API exposed to renderer
├── renderer/
│   ├── index.tsx                   # React entry point
│   ├── App.tsx                     # Root layout: tab bar + sidebar + terminal area
│   ├── store/
│   │   ├── index.ts                # Zustand store definition
│   │   └── types.ts                # TypeScript types for state
│   ├── components/
│   │   ├── TabBar.tsx              # Project group tabs
│   │   ├── Sidebar.tsx             # Quick launch + terminal list + status bar
│   │   ├── QuickLaunch.tsx         # Preset buttons
│   │   ├── TerminalList.tsx        # Terminal entries with filter
│   │   ├── TerminalEntry.tsx       # Single terminal list item
│   │   ├── TerminalArea.tsx        # Split pane container
│   │   ├── TerminalPane.tsx        # Single xterm.js instance + header
│   │   ├── CommandPalette.tsx      # Cmd+Shift+P palette
│   │   ├── QuickSwitcher.tsx       # Cmd+K switcher
│   │   └── StatusBar.tsx           # Bottom status bar
│   ├── hooks/
│   │   ├── useTerminal.ts          # xterm.js lifecycle hook
│   │   ├── useShortcuts.ts         # Keyboard shortcut registration
│   │   └── usePty.ts              # IPC communication with PTY manager
│   └── theme/
│       ├── colors.ts               # Shared color config (app + terminal)
│       └── xterm-theme.ts          # xterm.js ANSI color theme
├── shared/
│   └── types.ts                    # Shared types (IPC payloads, preset schema, etc.)
tests/
├── main/
│   ├── pty-manager.test.ts
│   ├── session-store.test.ts
│   ├── process-scanner.test.ts
│   └── tmux.test.ts
├── renderer/
│   ├── store.test.ts
│   ├── TabBar.test.tsx
│   ├── Sidebar.test.tsx
│   ├── TerminalList.test.tsx
│   ├── CommandPalette.test.tsx
│   └── QuickSwitcher.test.tsx
└── shared/
    └── types.test.ts
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `package.json`, `tsconfig.json`, `electron-builder.yml`, `tailwind.config.js`, `postcss.config.js`, `webpack.main.config.ts`, `webpack.renderer.config.ts`, `.gitignore` (update), `src/main/index.ts`, `src/main/preload.ts`, `src/renderer/index.tsx`, `src/renderer/App.tsx`, `src/renderer/index.html`

- [ ] **Step 1: Initialize npm project and install dependencies**

```bash
cd /Users/osemdynamics/Desktop/Dispatch
npm init -y
npm install --save electron electron-builder react react-dom xterm xterm-addon-fit xterm-addon-webgl node-pty zustand fuse.js
npm install --save-dev typescript @types/react @types/react-dom @types/node ts-loader css-loader style-loader postcss-loader tailwindcss autoprefixer webpack webpack-cli html-webpack-plugin electron-rebuild vitest @testing-library/react @testing-library/jest-dom jsdom happy-dom
```

- [ ] **Step 2: Create TypeScript config**

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "jsx": "react-jsx",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "baseUrl": ".",
    "paths": {
      "@shared/*": ["src/shared/*"],
      "@main/*": ["src/main/*"],
      "@renderer/*": ["src/renderer/*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

- [ ] **Step 3: Create Electron main process entry**

```typescript
// src/main/index.ts
import { app, BrowserWindow } from 'electron';
import path from 'path';

let mainWindow: BrowserWindow | null = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#0a0a1a',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (process.env.NODE_ENV === 'development') {
    mainWindow.loadURL('http://localhost:8080');
  } else {
    mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
  }
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
```

- [ ] **Step 4: Create preload script with empty API surface**

```typescript
// src/main/preload.ts
import { contextBridge } from 'electron';

contextBridge.exposeInMainWorld('dispatch', {
  pty: {
    spawn: async (_opts: unknown) => {},
    write: (_id: string, _data: string) => {},
    resize: (_id: string, _cols: number, _rows: number) => {},
    kill: (_id: string) => {},
    onData: (_cb: (id: string, data: string) => void) => {},
    onExit: (_cb: (id: string, code: number, signal: number) => void) => {},
  },
  state: {
    load: async () => ({}),
    save: async (_state: unknown) => {},
  },
  scanner: {
    onResults: (_cb: (results: unknown[]) => void) => {},
    attach: async (_pid: number) => {},
  },
});
```

- [ ] **Step 5: Create minimal React entry and App shell**

```typescript
// src/renderer/index.tsx
import React from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import './index.css';

const root = createRoot(document.getElementById('root')!);
root.render(<App />);
```

```typescript
// src/renderer/App.tsx
import React from 'react';

export function App() {
  return (
    <div className="flex flex-col h-screen bg-[#0a0a1a] text-white">
      <div className="h-10 bg-[#1a1a2e] border-b border-[#333] flex items-center px-4 text-sm text-gray-400">
        Dispatch
      </div>
      <div className="flex flex-1 overflow-hidden">
        <div className="w-56 bg-[#0f0f23] border-r border-[#333]">
          Sidebar
        </div>
        <div className="flex-1 bg-[#0a0a1a] flex items-center justify-center text-gray-600">
          No terminal open
        </div>
      </div>
    </div>
  );
}
```

```html
<!-- src/renderer/index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Dispatch</title>
</head>
<body>
  <div id="root"></div>
</body>
</html>
```

- [ ] **Step 6: Create Tailwind config and CSS entry**

```javascript
// tailwind.config.js
module.exports = {
  content: ['./src/renderer/**/*.{tsx,ts,html}'],
  theme: {
    extend: {},
  },
  plugins: [],
};
```

```javascript
// postcss.config.js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

```css
/* src/renderer/index.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  padding: 0;
  overflow: hidden;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
```

- [ ] **Step 7: Create webpack configs for main and renderer**

```typescript
// webpack.main.config.ts
import path from 'path';
import type { Configuration } from 'webpack';

const config: Configuration = {
  mode: process.env.NODE_ENV === 'production' ? 'production' : 'development',
  entry: { index: './src/main/index.ts', preload: './src/main/preload.ts' },
  target: 'electron-main',
  module: {
    rules: [{ test: /\.ts$/, use: 'ts-loader', exclude: /node_modules/ }],
  },
  resolve: { extensions: ['.ts', '.js'] },
  output: { path: path.resolve(__dirname, 'dist/main'), filename: '[name].js' },
  externals: { 'node-pty': 'commonjs node-pty' },
};

export default config;
```

```typescript
// webpack.renderer.config.ts
import path from 'path';
import HtmlWebpackPlugin from 'html-webpack-plugin';
import type { Configuration } from 'webpack';

const config: Configuration = {
  mode: process.env.NODE_ENV === 'production' ? 'production' : 'development',
  entry: './src/renderer/index.tsx',
  target: 'web',
  module: {
    rules: [
      { test: /\.tsx?$/, use: 'ts-loader', exclude: /node_modules/ },
      { test: /\.css$/, use: ['style-loader', 'css-loader', 'postcss-loader'] },
    ],
  },
  resolve: { extensions: ['.tsx', '.ts', '.js'] },
  output: { path: path.resolve(__dirname, 'dist/renderer'), filename: 'bundle.js' },
  plugins: [
    new HtmlWebpackPlugin({ template: './src/renderer/index.html' }),
  ],
  devServer: { port: 8080, hot: true },
};

export default config;
```

- [ ] **Step 8: Add npm scripts and verify build**

Add to `package.json`:
```json
{
  "main": "dist/main/index.js",
  "scripts": {
    "dev:renderer": "webpack serve --config webpack.renderer.config.ts",
    "dev:main": "webpack --config webpack.main.config.ts --watch",
    "build:renderer": "NODE_ENV=production webpack --config webpack.renderer.config.ts",
    "build:main": "NODE_ENV=production webpack --config webpack.main.config.ts",
    "build": "npm run build:main && npm run build:renderer",
    "start": "electron dist/main/index.js",
    "test": "vitest",
    "postinstall": "electron-rebuild"
  }
}
```

Run: `npm run build`
Expected: Clean build, `dist/` directory created with main and renderer bundles.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: scaffold Electron + React + TypeScript project"
```

---

### Task 2: Shared Types

**Files:**
- Create: `src/shared/types.ts`, `tests/shared/types.test.ts`

- [ ] **Step 1: Write type validation tests**

```typescript
// tests/shared/types.test.ts
import { describe, it, expect } from 'vitest';
import {
  type Preset,
  type TerminalEntry,
  type ProjectGroup,
  type AppState,
  type SpawnOptions,
  TerminalStatus,
  DEFAULT_PRESETS,
} from '../src/shared/types';

describe('shared types', () => {
  it('DEFAULT_PRESETS has 4 entries with required fields', () => {
    expect(DEFAULT_PRESETS).toHaveLength(4);
    for (const p of DEFAULT_PRESETS) {
      expect(p.name).toBeTruthy();
      expect(p.command).toBeTruthy();
      expect(p.color).toMatch(/^#/);
      expect(p.icon).toBeTruthy();
    }
  });

  it('TerminalStatus enum has all expected values', () => {
    expect(TerminalStatus.ACTIVE).toBe('ACTIVE');
    expect(TerminalStatus.RUNNING).toBe('RUNNING');
    expect(TerminalStatus.EXITED).toBe('EXITED');
    expect(TerminalStatus.EXTERNAL).toBe('EXTERNAL');
    expect(TerminalStatus.ATTACHING).toBe('ATTACHING');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/shared/types.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement shared types**

```typescript
// src/shared/types.ts
export enum TerminalStatus {
  ACTIVE = 'ACTIVE',
  RUNNING = 'RUNNING',
  EXITED = 'EXITED',
  EXTERNAL = 'EXTERNAL',
  ATTACHING = 'ATTACHING',
}

export interface Preset {
  name: string;
  command: string;
  color: string;
  icon: string;
  env?: Record<string, string>;
}

export interface TerminalEntry {
  id: string;
  presetName?: string;
  command: string;
  cwd: string;
  status: TerminalStatus;
  exitCode?: number;
  exitSignal?: number;
  pid?: number;
  isExternal?: boolean;
}

export interface ProjectGroup {
  id: string;
  label: string;
  cwd?: string;        // undefined for custom groups
  isCustom: boolean;
  terminalIds: string[];
}

export interface AppState {
  groups: ProjectGroup[];
  activeGroupId: string | null;
  activeTerminalId: string | null;
  windowBounds: { x: number; y: number; width: number; height: number };
  sidebarWidth: number;
}

export interface SpawnOptions {
  shell?: string;
  cwd: string;
  command?: string;
  env?: Record<string, string>;
}

export interface Settings {
  shell: string;
  fontFamily: string;
  fontSize: number;
  lineHeight: number;
  scanInterval: number;
  keybindings: Record<string, string>;
}

export const DEFAULT_SETTINGS: Settings = {
  shell: process.env.SHELL || '/bin/sh',
  fontFamily: 'monospace',
  fontSize: 13,
  lineHeight: 1.2,
  scanInterval: 10000,
  keybindings: {},
};

export const DEFAULT_PRESETS: Preset[] = [
  { name: 'Claude Code', command: 'claude', color: '#0f3460', icon: 'brain' },
  { name: 'Resume Session', command: 'claude --resume', color: '#e94560', icon: 'rotate-ccw' },
  { name: 'Skip Permissions', command: 'claude --dangerously-skip-permissions', color: '#f5a623', icon: 'zap' },
  { name: 'Shell', command: '$SHELL', color: '#888888', icon: 'terminal', env: {} },
];

// IPC channel names
export const IPC = {
  PTY_SPAWN: 'pty:spawn',
  PTY_DATA: 'pty:data',
  PTY_RESIZE: 'pty:resize',
  PTY_EXIT: 'pty:exit',
  PTY_KILL: 'pty:kill',
  SCANNER_RESULTS: 'scanner:results',
  SCANNER_ATTACH: 'scanner:attach',
  STATE_SAVE: 'state:save',
  STATE_LOAD: 'state:load',
} as const;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/shared/types.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/shared/types.ts tests/shared/types.test.ts
git commit -m "feat: add shared types, presets, and IPC channel constants"
```

---

### Task 3: Session Store

**Files:**
- Create: `src/main/session-store.ts`, `tests/main/session-store.test.ts`

- [ ] **Step 1: Write failing tests for session store**

```typescript
// tests/main/session-store.test.ts
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { SessionStore } from '../../src/main/session-store';

describe('SessionStore', () => {
  let tmpDir: string;
  let store: SessionStore;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dispatch-test-'));
    store = new SessionStore(tmpDir);
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  describe('state', () => {
    it('returns default state when state.json does not exist', async () => {
      const state = await store.loadState();
      expect(state.groups).toEqual([]);
      expect(state.activeGroupId).toBeNull();
    });

    it('saves and loads state', async () => {
      const state = { groups: [], activeGroupId: 'g1', activeTerminalId: null, windowBounds: { x: 0, y: 0, width: 1200, height: 800 }, sidebarWidth: 220 };
      await store.saveState(state);
      const loaded = await store.loadState();
      expect(loaded.activeGroupId).toBe('g1');
    });

    it('recovers from corrupted state.json', async () => {
      fs.writeFileSync(path.join(tmpDir, 'state.json'), '{invalid json!!}');
      const state = await store.loadState();
      expect(state.groups).toEqual([]);
    });

    it('creates backup before overwriting state', async () => {
      const state1 = { groups: [], activeGroupId: 'g1', activeTerminalId: null, windowBounds: { x: 0, y: 0, width: 1200, height: 800 }, sidebarWidth: 220 };
      await store.saveState(state1);
      const state2 = { ...state1, activeGroupId: 'g2' };
      await store.saveState(state2);
      const backup = JSON.parse(fs.readFileSync(path.join(tmpDir, 'state.json.bak'), 'utf-8'));
      expect(backup.activeGroupId).toBe('g1');
    });
  });

  describe('presets', () => {
    it('returns default presets when presets.json does not exist', async () => {
      const presets = await store.loadPresets();
      expect(presets).toHaveLength(4);
      expect(presets[0].name).toBe('Claude Code');
    });

    it('saves and loads custom presets', async () => {
      const presets = [{ name: 'Test', command: 'echo hi', color: '#fff', icon: 'test' }];
      await store.savePresets(presets);
      const loaded = await store.loadPresets();
      expect(loaded).toHaveLength(1);
      expect(loaded[0].name).toBe('Test');
    });
  });

  describe('settings', () => {
    it('returns default settings when settings.json does not exist', async () => {
      const settings = await store.loadSettings();
      expect(settings.fontSize).toBe(13);
      expect(settings.scanInterval).toBe(10000);
    });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/main/session-store.test.ts`
Expected: FAIL — SessionStore not found

- [ ] **Step 3: Implement SessionStore**

```typescript
// src/main/session-store.ts
import fs from 'fs/promises';
import fsSync from 'fs';
import path from 'path';
import { type AppState, type Preset, type Settings, DEFAULT_PRESETS, DEFAULT_SETTINGS } from '../shared/types';

const DEFAULT_STATE: AppState = {
  groups: [],
  activeGroupId: null,
  activeTerminalId: null,
  windowBounds: { x: 0, y: 0, width: 1200, height: 800 },
  sidebarWidth: 220,
};

export class SessionStore {
  private dir: string;

  constructor(configDir: string) {
    this.dir = configDir;
    if (!fsSync.existsSync(this.dir)) {
      fsSync.mkdirSync(this.dir, { recursive: true });
    }
  }

  private filePath(name: string): string {
    return path.join(this.dir, name);
  }

  private async readJson<T>(name: string, fallback: T): Promise<T> {
    try {
      const raw = await fs.readFile(this.filePath(name), 'utf-8');
      return JSON.parse(raw) as T;
    } catch {
      return fallback;
    }
  }

  private async writeJson(name: string, data: unknown): Promise<void> {
    await fs.writeFile(this.filePath(name), JSON.stringify(data, null, 2), 'utf-8');
  }

  async loadState(): Promise<AppState> {
    return this.readJson('state.json', DEFAULT_STATE);
  }

  async saveState(state: AppState): Promise<void> {
    // Backup existing state before overwriting
    const statePath = this.filePath('state.json');
    try {
      await fs.access(statePath);
      await fs.copyFile(statePath, this.filePath('state.json.bak'));
    } catch {
      // No existing file to backup
    }
    await this.writeJson('state.json', state);
  }

  async loadPresets(): Promise<Preset[]> {
    return this.readJson('presets.json', DEFAULT_PRESETS);
  }

  async savePresets(presets: Preset[]): Promise<void> {
    await this.writeJson('presets.json', presets);
  }

  async loadSettings(): Promise<Settings> {
    return this.readJson('settings.json', DEFAULT_SETTINGS);
  }

  async saveSettings(settings: Settings): Promise<void> {
    await this.writeJson('settings.json', settings);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/main/session-store.test.ts`
Expected: PASS (all 6 tests)

- [ ] **Step 5: Commit**

```bash
git add src/main/session-store.ts tests/main/session-store.test.ts
git commit -m "feat: add SessionStore with state/presets/settings persistence"
```

---

### Task 4: PTY Manager

**Files:**
- Create: `src/main/pty-manager.ts`, `tests/main/pty-manager.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// tests/main/pty-manager.test.ts
import { describe, it, expect, afterEach } from 'vitest';
import { PtyManager } from '../../src/main/pty-manager';
import os from 'os';

describe('PtyManager', () => {
  let manager: PtyManager;

  afterEach(() => {
    manager?.killAll();
  });

  it('spawns a terminal and returns an id', () => {
    manager = new PtyManager();
    const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh' });
    expect(id).toBeTruthy();
    expect(manager.get(id)).toBeDefined();
  });

  it('receives data from spawned terminal', async () => {
    manager = new PtyManager();
    const received: string[] = [];
    manager.onData((id, data) => received.push(data));
    const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh' });
    manager.write(id, 'echo hello\r');
    await new Promise((r) => setTimeout(r, 500));
    expect(received.length).toBeGreaterThan(0);
  });

  it('fires onExit when process ends', async () => {
    manager = new PtyManager();
    let exitId = '';
    let exitCode = -1;
    manager.onExit((id, code) => { exitId = id; exitCode = code; });
    const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh' });
    manager.write(id, 'exit 0\r');
    await new Promise((r) => setTimeout(r, 500));
    expect(exitId).toBe(id);
    expect(exitCode).toBe(0);
  });

  it('kill removes the terminal', () => {
    manager = new PtyManager();
    const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh' });
    manager.kill(id);
    expect(manager.get(id)).toBeUndefined();
  });

  it('resize does not throw for valid terminal', () => {
    manager = new PtyManager();
    const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh' });
    expect(() => manager.resize(id, 120, 40)).not.toThrow();
  });

  it('spawn falls back to /bin/sh if shell not found', () => {
    manager = new PtyManager();
    const id = manager.spawn({ cwd: os.homedir(), shell: '/nonexistent/shell' });
    // Should have spawned with fallback — id should exist
    expect(id).toBeTruthy();
  });

  it('spawn falls back to homedir if cwd does not exist', () => {
    manager = new PtyManager();
    const id = manager.spawn({ cwd: '/nonexistent/path', shell: '/bin/sh' });
    expect(id).toBeTruthy();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/main/pty-manager.test.ts`
Expected: FAIL — PtyManager not found

- [ ] **Step 3: Implement PtyManager**

```typescript
// src/main/pty-manager.ts
import * as pty from 'node-pty';
import os from 'os';
import fs from 'fs';
import { randomUUID } from 'crypto';
import type { SpawnOptions } from '../shared/types';

type DataCallback = (id: string, data: string) => void;
type ExitCallback = (id: string, exitCode: number, signal: number) => void;

export class PtyManager {
  private terminals = new Map<string, pty.IPty>();
  private dataCallbacks: DataCallback[] = [];
  private exitCallbacks: ExitCallback[] = [];

  spawn(opts: SpawnOptions): string {
    const id = randomUUID();
    let shell = opts.shell || process.env.SHELL || '/bin/sh';
    let cwd = opts.cwd;

    // Validate CWD exists, fallback to home
    if (!fs.existsSync(cwd)) {
      cwd = os.homedir();
    }

    let term: pty.IPty;
    try {
      term = pty.spawn(shell, [], {
        name: 'xterm-256color',
        cols: 80,
        rows: 24,
        cwd,
        env: { ...process.env, ...opts.env } as Record<string, string>,
      });
    } catch {
      // Fallback to /bin/sh if the requested shell fails
      shell = '/bin/sh';
      term = pty.spawn(shell, [], {
        name: 'xterm-256color',
        cols: 80,
        rows: 24,
        cwd,
        env: { ...process.env, ...opts.env } as Record<string, string>,
      });
    }

    this.terminals.set(id, term);

    term.onData((data) => {
      for (const cb of this.dataCallbacks) cb(id, data);
    });

    term.onExit(({ exitCode, signal }) => {
      this.terminals.delete(id);
      for (const cb of this.exitCallbacks) cb(id, exitCode, signal);
    });

    // If a command was specified, send it
    if (opts.command) {
      term.write(opts.command + '\r');
    }

    return id;
  }

  write(id: string, data: string): void {
    this.terminals.get(id)?.write(data);
  }

  resize(id: string, cols: number, rows: number): void {
    this.terminals.get(id)?.resize(cols, rows);
  }

  kill(id: string): void {
    const term = this.terminals.get(id);
    if (term) {
      term.kill();
      this.terminals.delete(id);
    }
  }

  killAll(): void {
    for (const [id] of this.terminals) {
      this.kill(id);
    }
  }

  get(id: string): pty.IPty | undefined {
    return this.terminals.get(id);
  }

  onData(cb: DataCallback): void {
    this.dataCallbacks.push(cb);
  }

  onExit(cb: ExitCallback): void {
    this.exitCallbacks.push(cb);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/main/pty-manager.test.ts`
Expected: PASS (all 7 tests)

- [ ] **Step 5: Commit**

```bash
git add src/main/pty-manager.ts tests/main/pty-manager.test.ts
git commit -m "feat: add PtyManager with spawn, data, exit, resize, kill"
```

---

### Task 5: IPC Bridge

**Files:**
- Create: `src/main/ipc.ts`
- Modify: `src/main/index.ts`, `src/main/preload.ts`

- [ ] **Step 1: Implement IPC handler registration**

```typescript
// src/main/ipc.ts
import { ipcMain, BrowserWindow } from 'electron';
import { PtyManager } from './pty-manager';
import { SessionStore } from './session-store';
import { IPC } from '../shared/types';

export function registerIpc(ptyManager: PtyManager, store: SessionStore): void {
  ipcMain.handle(IPC.PTY_SPAWN, async (_event, opts) => {
    return ptyManager.spawn(opts);
  });

  ipcMain.on(IPC.PTY_DATA, (_event, id: string, data: string) => {
    ptyManager.write(id, data);
  });

  ipcMain.on(IPC.PTY_RESIZE, (_event, id: string, cols: number, rows: number) => {
    ptyManager.resize(id, cols, rows);
  });

  ipcMain.on(IPC.PTY_KILL, (_event, id: string) => {
    ptyManager.kill(id);
  });

  ipcMain.handle(IPC.STATE_LOAD, async () => {
    return {
      state: await store.loadState(),
      presets: await store.loadPresets(),
      settings: await store.loadSettings(),
    };
  });

  ipcMain.handle(IPC.STATE_SAVE, async (_event, state) => {
    await store.saveState(state);
  });

  // Forward PTY events to renderer
  ptyManager.onData((id, data) => {
    const win = BrowserWindow.getAllWindows()[0];
    win?.webContents.send(IPC.PTY_DATA, id, data);
  });

  ptyManager.onExit((id, code, signal) => {
    const win = BrowserWindow.getAllWindows()[0];
    win?.webContents.send(IPC.PTY_EXIT, id, code, signal);
  });
}
```

- [ ] **Step 2: Update preload with real IPC calls**

```typescript
// src/main/preload.ts
import { contextBridge, ipcRenderer } from 'electron';
import { IPC } from '../shared/types';

contextBridge.exposeInMainWorld('dispatch', {
  pty: {
    spawn: (opts: unknown) => ipcRenderer.invoke(IPC.PTY_SPAWN, opts),
    write: (id: string, data: string) => ipcRenderer.send(IPC.PTY_DATA, id, data),
    resize: (id: string, cols: number, rows: number) => ipcRenderer.send(IPC.PTY_RESIZE, id, cols, rows),
    kill: (id: string) => ipcRenderer.send(IPC.PTY_KILL, id),
    onData: (cb: (id: string, data: string) => void) => {
      ipcRenderer.on(IPC.PTY_DATA, (_event, id, data) => cb(id, data));
    },
    onExit: (cb: (id: string, code: number, signal: number) => void) => {
      ipcRenderer.on(IPC.PTY_EXIT, (_event, id, code, signal) => cb(id, code, signal));
    },
  },
  state: {
    load: () => ipcRenderer.invoke(IPC.STATE_LOAD),
    save: (state: unknown) => ipcRenderer.invoke(IPC.STATE_SAVE, state),
  },
  scanner: {
    onResults: (cb: (results: unknown[]) => void) => {
      ipcRenderer.on(IPC.SCANNER_RESULTS, (_event, results) => cb(results));
    },
    attach: (pid: number) => ipcRenderer.invoke(IPC.SCANNER_ATTACH, pid),
  },
});
```

- [ ] **Step 3: Update main process to wire everything together**

```typescript
// src/main/index.ts
import { app, BrowserWindow } from 'electron';
import path from 'path';
import { PtyManager } from './pty-manager';
import { SessionStore } from './session-store';
import { registerIpc } from './ipc';

let mainWindow: BrowserWindow | null = null;

const ptyManager = new PtyManager();
const store = new SessionStore(
  path.join(app.getPath('home'), '.config', 'dispatch')
);

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#0a0a1a',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (process.env.NODE_ENV === 'development') {
    mainWindow.loadURL('http://localhost:8080');
  } else {
    mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
  }
}

app.whenReady().then(() => {
  registerIpc(ptyManager, store);
  createWindow();
});

app.on('window-all-closed', () => {
  ptyManager.killAll();
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
```

- [ ] **Step 4: Verify build succeeds**

Run: `npm run build`
Expected: Clean build

- [ ] **Step 5: Commit**

```bash
git add src/main/ipc.ts src/main/preload.ts src/main/index.ts
git commit -m "feat: wire IPC bridge between main and renderer"
```

---

### Task 6: Zustand Store

**Files:**
- Create: `src/renderer/store/types.ts`, `src/renderer/store/index.ts`, `tests/renderer/store.test.ts`

- [ ] **Step 1: Write failing store tests**

```typescript
// tests/renderer/store.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { useStore } from '../../src/renderer/store';
import { TerminalStatus } from '../../src/shared/types';

describe('useStore', () => {
  beforeEach(() => {
    useStore.setState(useStore.getInitialState());
  });

  it('starts with empty state', () => {
    const state = useStore.getState();
    expect(state.groups).toEqual([]);
    expect(state.terminals).toEqual({});
    expect(state.activeGroupId).toBeNull();
  });

  it('addGroup creates a new project group', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const { groups } = useStore.getState();
    expect(groups).toHaveLength(1);
    expect(groups[0].label).toBe('foo');
    expect(groups[0].cwd).toBe('~/Projects/foo');
  });

  it('addTerminal adds a terminal to a group', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const groupId = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(groupId, {
      id: 't1',
      command: 'claude',
      cwd: '~/Projects/foo',
      status: TerminalStatus.RUNNING,
    });
    const { terminals, groups } = useStore.getState();
    expect(terminals['t1']).toBeDefined();
    expect(groups[0].terminalIds).toContain('t1');
  });

  it('setActiveTerminal updates active state', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const groupId = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(groupId, {
      id: 't1',
      command: 'claude',
      cwd: '~/Projects/foo',
      status: TerminalStatus.RUNNING,
    });
    useStore.getState().setActiveTerminal('t1');
    expect(useStore.getState().activeTerminalId).toBe('t1');
    expect(useStore.getState().terminals['t1'].status).toBe(TerminalStatus.ACTIVE);
  });

  it('removeTerminal cleans up terminal and group reference', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const groupId = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(groupId, {
      id: 't1',
      command: 'claude',
      cwd: '~/Projects/foo',
      status: TerminalStatus.RUNNING,
    });
    useStore.getState().removeTerminal('t1');
    expect(useStore.getState().terminals['t1']).toBeUndefined();
    expect(useStore.getState().groups[0].terminalIds).not.toContain('t1');
  });

  it('updateTerminalStatus changes status', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const groupId = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(groupId, {
      id: 't1',
      command: 'claude',
      cwd: '~/Projects/foo',
      status: TerminalStatus.RUNNING,
    });
    useStore.getState().updateTerminalStatus('t1', TerminalStatus.EXITED, 0);
    const t = useStore.getState().terminals['t1'];
    expect(t.status).toBe(TerminalStatus.EXITED);
    expect(t.exitCode).toBe(0);
  });

  it('findOrCreateGroup returns existing group for same cwd', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const existing = useStore.getState().groups[0].id;
    const found = useStore.getState().findOrCreateGroup('~/Projects/foo');
    expect(found).toBe(existing);
  });

  it('findOrCreateGroup creates new group for unknown cwd', () => {
    const id = useStore.getState().findOrCreateGroup('~/Projects/bar');
    expect(useStore.getState().groups).toHaveLength(1);
    expect(useStore.getState().groups[0].id).toBe(id);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/renderer/store.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement Zustand store**

```typescript
// src/renderer/store/types.ts
import type { TerminalEntry, ProjectGroup, Preset, Settings } from '../../shared/types';

export interface StoreState {
  groups: ProjectGroup[];
  terminals: Record<string, TerminalEntry>;
  activeGroupId: string | null;
  activeTerminalId: string | null;
  presets: Preset[];
  settings: Settings;
  sidebarWidth: number;
  filterText: string;
}

export interface StoreActions {
  addGroup: (cwd: string | undefined, label: string) => void;
  removeGroup: (id: string) => void;
  setActiveGroup: (id: string) => void;
  reorderGroups: (fromIndex: number, toIndex: number) => void;
  findOrCreateGroup: (cwd: string) => string;
  addTerminal: (groupId: string, terminal: TerminalEntry) => void;
  removeTerminal: (id: string) => void;
  setActiveTerminal: (id: string) => void;
  updateTerminalStatus: (id: string, status: TerminalEntry['status'], exitCode?: number) => void;
  moveTerminal: (terminalId: string, fromGroupId: string, toGroupId: string) => void;
  setPresets: (presets: Preset[]) => void;
  setSettings: (settings: Settings) => void;
  setFilterText: (text: string) => void;
}
```

```typescript
// src/renderer/store/index.ts
import { create } from 'zustand';
import { randomUUID } from 'crypto';
import { TerminalStatus, DEFAULT_PRESETS, DEFAULT_SETTINGS } from '../../shared/types';
import type { TerminalEntry } from '../../shared/types';
import type { StoreState, StoreActions } from './types';

const genId = () => typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2);

export const useStore = create<StoreState & StoreActions>()((set, get) => ({
  groups: [],
  terminals: {},
  activeGroupId: null,
  activeTerminalId: null,
  presets: DEFAULT_PRESETS,
  settings: DEFAULT_SETTINGS,
  sidebarWidth: 220,
  filterText: '',

  addGroup: (cwd, label) => {
    const id = genId();
    set((s) => ({
      groups: [...s.groups, { id, label, cwd: cwd || undefined, isCustom: !cwd, terminalIds: [] }],
      activeGroupId: s.activeGroupId || id,
    }));
  },

  removeGroup: (id) => {
    set((s) => {
      const group = s.groups.find((g) => g.id === id);
      const newTerminals = { ...s.terminals };
      group?.terminalIds.forEach((tid) => delete newTerminals[tid]);
      return {
        groups: s.groups.filter((g) => g.id !== id),
        terminals: newTerminals,
        activeGroupId: s.activeGroupId === id ? (s.groups[0]?.id ?? null) : s.activeGroupId,
      };
    });
  },

  setActiveGroup: (id) => set({ activeGroupId: id }),

  reorderGroups: (fromIndex, toIndex) => {
    set((s) => {
      const groups = [...s.groups];
      const [moved] = groups.splice(fromIndex, 1);
      groups.splice(toIndex, 0, moved);
      return { groups };
    });
  },

  findOrCreateGroup: (cwd) => {
    const existing = get().groups.find((g) => g.cwd === cwd);
    if (existing) return existing.id;
    const label = cwd.split('/').pop() || cwd;
    const id = genId();
    set((s) => ({
      groups: [...s.groups, { id, label, cwd, isCustom: false, terminalIds: [] }],
      activeGroupId: s.activeGroupId || id,
    }));
    return id;
  },

  addTerminal: (groupId, terminal) => {
    set((s) => ({
      terminals: { ...s.terminals, [terminal.id]: terminal },
      groups: s.groups.map((g) =>
        g.id === groupId ? { ...g, terminalIds: [...g.terminalIds, terminal.id] } : g
      ),
    }));
  },

  removeTerminal: (id) => {
    set((s) => ({
      terminals: Object.fromEntries(Object.entries(s.terminals).filter(([k]) => k !== id)),
      groups: s.groups.map((g) => ({
        ...g,
        terminalIds: g.terminalIds.filter((tid) => tid !== id),
      })),
      activeTerminalId: s.activeTerminalId === id ? null : s.activeTerminalId,
    }));
  },

  setActiveTerminal: (id) => {
    set((s) => {
      const newTerminals = { ...s.terminals };
      // Deactivate previous
      if (s.activeTerminalId && newTerminals[s.activeTerminalId]) {
        const prev = newTerminals[s.activeTerminalId];
        if (prev.status === TerminalStatus.ACTIVE) {
          newTerminals[s.activeTerminalId] = { ...prev, status: TerminalStatus.RUNNING };
        }
      }
      // Activate new
      if (newTerminals[id] && newTerminals[id].status === TerminalStatus.RUNNING) {
        newTerminals[id] = { ...newTerminals[id], status: TerminalStatus.ACTIVE };
      }
      return { activeTerminalId: id, terminals: newTerminals };
    });
  },

  updateTerminalStatus: (id, status, exitCode) => {
    set((s) => ({
      terminals: {
        ...s.terminals,
        [id]: s.terminals[id]
          ? { ...s.terminals[id], status, exitCode: exitCode ?? s.terminals[id].exitCode }
          : s.terminals[id],
      },
    }));
  },

  moveTerminal: (terminalId, fromGroupId, toGroupId) => {
    set((s) => ({
      groups: s.groups.map((g) => {
        if (g.id === fromGroupId) return { ...g, terminalIds: g.terminalIds.filter((t) => t !== terminalId) };
        if (g.id === toGroupId) return { ...g, terminalIds: [...g.terminalIds, terminalId] };
        return g;
      }),
    }));
  },

  setPresets: (presets) => set({ presets }),
  setSettings: (settings) => set({ settings }),
  setFilterText: (text) => set({ filterText: text }),
}));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/renderer/store.test.ts`
Expected: PASS (all 8 tests)

- [ ] **Step 5: Commit**

```bash
git add src/renderer/store/ tests/renderer/store.test.ts
git commit -m "feat: add Zustand store with groups, terminals, presets management"
```

---

### Task 7: Theme & Colors

**Files:**
- Create: `src/renderer/theme/colors.ts`, `src/renderer/theme/xterm-theme.ts`

- [ ] **Step 1: Create color config**

```typescript
// src/renderer/theme/colors.ts
export const colors = {
  bg: {
    primary: '#0a0a1a',
    secondary: '#0f0f23',
    tertiary: '#1a1a2e',
    elevated: '#16213e',
  },
  border: {
    default: '#333333',
    subtle: '#222222',
  },
  text: {
    primary: '#eeeeee',
    secondary: '#cccccc',
    muted: '#888888',
    dim: '#555555',
  },
  accent: {
    primary: '#e94560',
    blue: '#0f3460',
    blueLight: '#53a8ff',
    yellow: '#f5a623',
    green: '#4caf50',
  },
  status: {
    active: { bg: '#0f3460', text: '#53a8ff' },
    running: { bg: '#1a3a1a', text: '#4caf50' },
    exited: { bg: '#3a1a1a', text: '#e94560' },
    external: { bg: '#2a2a1a', text: '#f5a623' },
    attaching: { bg: '#1a2a3a', text: '#53a8ff' },
  },
};
```

```typescript
// src/renderer/theme/xterm-theme.ts
import type { ITheme } from 'xterm';

export const xtermTheme: ITheme = {
  background: '#0a0a1a',
  foreground: '#cccccc',
  cursor: '#e94560',
  cursorAccent: '#0a0a1a',
  selectionBackground: '#16213e',
  selectionForeground: '#eeeeee',
  black: '#0a0a1a',
  red: '#e94560',
  green: '#4caf50',
  yellow: '#f5a623',
  blue: '#53a8ff',
  magenta: '#c678dd',
  cyan: '#56b6c2',
  white: '#cccccc',
  brightBlack: '#555555',
  brightRed: '#ff6b81',
  brightGreen: '#69f0ae',
  brightYellow: '#ffd740',
  brightBlue: '#82b1ff',
  brightMagenta: '#e1acff',
  brightCyan: '#84ffff',
  brightWhite: '#ffffff',
};
```

- [ ] **Step 2: Commit**

```bash
git add src/renderer/theme/
git commit -m "feat: add dark theme colors and xterm.js ANSI palette"
```

---

### Task 8: TerminalPane Component (xterm.js integration)

**Files:**
- Create: `src/renderer/hooks/useTerminal.ts`, `src/renderer/hooks/usePty.ts`, `src/renderer/components/TerminalPane.tsx`

- [ ] **Step 1: Create usePty hook for IPC**

```typescript
// src/renderer/hooks/usePty.ts
import { useEffect, useRef } from 'react';

declare global {
  interface Window {
    dispatch: {
      pty: {
        spawn: (opts: unknown) => Promise<string>;
        write: (id: string, data: string) => void;
        resize: (id: string, cols: number, rows: number) => void;
        kill: (id: string) => void;
        onData: (cb: (id: string, data: string) => void) => void;
        onExit: (cb: (id: string, code: number, signal: number) => void) => void;
      };
      state: {
        load: () => Promise<unknown>;
        save: (state: unknown) => Promise<void>;
      };
      scanner: {
        onResults: (cb: (results: unknown[]) => void) => void;
        attach: (pid: number) => Promise<void>;
      };
    };
  }
}

export function usePty() {
  return window.dispatch.pty;
}

export function useStateApi() {
  return window.dispatch.state;
}

export function useScannerApi() {
  return window.dispatch.scanner;
}
```

- [ ] **Step 2: Create useTerminal hook**

```typescript
// src/renderer/hooks/useTerminal.ts
import { useEffect, useRef, useCallback } from 'react';
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import { WebglAddon } from 'xterm-addon-webgl';
import { xtermTheme } from '../theme/xterm-theme';

interface UseTerminalOptions {
  fontSize?: number;
  fontFamily?: string;
  lineHeight?: number;
}

export function useTerminal(containerRef: React.RefObject<HTMLDivElement | null>, opts?: UseTerminalOptions) {
  const termRef = useRef<Terminal | null>(null);
  const fitRef = useRef<FitAddon | null>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    const term = new Terminal({
      theme: xtermTheme,
      fontSize: opts?.fontSize ?? 13,
      fontFamily: opts?.fontFamily ?? 'monospace',
      lineHeight: opts?.lineHeight ?? 1.2,
      cursorBlink: true,
      allowProposedApi: true,
    });

    const fit = new FitAddon();
    term.loadAddon(fit);

    term.open(containerRef.current);

    // Try WebGL, fall back to canvas
    try {
      const webgl = new WebglAddon();
      webgl.onContextLoss(() => webgl.dispose());
      term.loadAddon(webgl);
    } catch {
      // Canvas renderer is the default fallback
    }

    fit.fit();
    termRef.current = term;
    fitRef.current = fit;

    const resizeObserver = new ResizeObserver(() => fit.fit());
    resizeObserver.observe(containerRef.current);

    return () => {
      resizeObserver.disconnect();
      term.dispose();
      termRef.current = null;
      fitRef.current = null;
    };
  }, [containerRef, opts?.fontSize, opts?.fontFamily, opts?.lineHeight]);

  const fit = useCallback(() => fitRef.current?.fit(), []);

  return { terminal: termRef, fit };
}
```

- [ ] **Step 3: Create TerminalPane component**

```typescript
// src/renderer/components/TerminalPane.tsx
import React, { useRef, useEffect } from 'react';
import { useTerminal } from '../hooks/useTerminal';
import { usePty } from '../hooks/usePty';
import { useStore } from '../store';
import { TerminalStatus } from '../../shared/types';
import { colors } from '../theme/colors';

interface TerminalPaneProps {
  terminalId: string;
}

export function TerminalPane({ terminalId }: TerminalPaneProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const { terminal, fit } = useTerminal(containerRef);
  const pty = usePty();
  const entry = useStore((s) => s.terminals[terminalId]);
  const settings = useStore((s) => s.settings);

  useEffect(() => {
    if (!terminal.current) return;

    // Listen for data from this terminal's PTY
    pty.onData((id, data) => {
      if (id === terminalId) {
        terminal.current?.write(data);
      }
    });

    // Send user input to PTY
    const disposable = terminal.current.onData((data) => {
      pty.write(terminalId, data);
    });

    // Handle resize
    const resizeDisposable = terminal.current.onResize(({ cols, rows }) => {
      pty.resize(terminalId, cols, rows);
    });

    return () => {
      disposable.dispose();
      resizeDisposable.dispose();
    };
  }, [terminal.current, terminalId, pty]);

  if (!entry) return null;

  const isExited = entry.status === TerminalStatus.EXITED;

  return (
    <div className="flex flex-col flex-1 overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-3 py-1.5 border-b"
        style={{ backgroundColor: colors.bg.tertiary, borderColor: colors.border.default }}>
        <div className="flex items-center gap-2">
          <span style={{ color: colors.accent.primary }}>●</span>
          <span className="text-xs" style={{ color: colors.text.secondary }}>
            {entry.command} — {entry.cwd}
          </span>
        </div>
        <div className="flex gap-3 text-xs" style={{ color: colors.text.dim }}>
          <span>Split ⌘D</span>
          <span>Close ⌘W</span>
        </div>
      </div>

      {/* Terminal */}
      <div ref={containerRef} className="flex-1 relative">
        {isExited && (
          <div className="absolute inset-0 flex items-center justify-center bg-black/60 z-10">
            <div className="text-center">
              <p style={{ color: colors.text.muted }}>
                Process exited with code {entry.exitCode ?? 'unknown'}
              </p>
              <p className="mt-2 text-xs" style={{ color: colors.text.dim }}>
                Press any key to close or click Restart
              </p>
              <button
                className="mt-3 px-4 py-1.5 rounded text-xs"
                style={{ backgroundColor: colors.accent.blue, color: colors.accent.blueLight }}
                onClick={() => {/* restart logic handled by parent */}}
              >
                Restart
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Verify build**

Run: `npm run build`
Expected: Clean build

- [ ] **Step 5: Commit**

```bash
git add src/renderer/hooks/ src/renderer/components/TerminalPane.tsx
git commit -m "feat: add TerminalPane with xterm.js, PTY IPC, and exit overlay"
```

---

### Task 9: TabBar Component

**Files:**
- Create: `src/renderer/components/TabBar.tsx`, `tests/renderer/TabBar.test.tsx`

- [ ] **Step 1: Write failing test**

```typescript
// tests/renderer/TabBar.test.tsx
import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { TabBar } from '../../src/renderer/components/TabBar';
import { useStore } from '../../src/renderer/store';

describe('TabBar', () => {
  beforeEach(() => {
    useStore.setState(useStore.getInitialState());
  });

  it('renders no tabs when no groups exist', () => {
    render(<TabBar />);
    expect(screen.queryByRole('tab')).toBeNull();
  });

  it('renders tabs for each group', () => {
    useStore.getState().addGroup('~/foo', 'foo');
    useStore.getState().addGroup('~/bar', 'bar');
    render(<TabBar />);
    expect(screen.getByText('foo')).toBeTruthy();
    expect(screen.getByText('bar')).toBeTruthy();
  });

  it('highlights the active tab', () => {
    useStore.getState().addGroup('~/foo', 'foo');
    useStore.getState().addGroup('~/bar', 'bar');
    const firstId = useStore.getState().groups[0].id;
    useStore.getState().setActiveGroup(firstId);
    render(<TabBar />);
    const tab = screen.getByText('foo').closest('[role="tab"]');
    expect(tab?.getAttribute('aria-selected')).toBe('true');
  });

  it('clicking a tab sets it active', () => {
    useStore.getState().addGroup('~/foo', 'foo');
    useStore.getState().addGroup('~/bar', 'bar');
    render(<TabBar />);
    fireEvent.click(screen.getByText('bar'));
    expect(useStore.getState().activeGroupId).toBe(useStore.getState().groups[1].id);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/renderer/TabBar.test.tsx`
Expected: FAIL

- [ ] **Step 3: Implement TabBar**

```typescript
// src/renderer/components/TabBar.tsx
import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

export function TabBar() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const setActiveGroup = useStore((s) => s.setActiveGroup);
  const addGroup = useStore((s) => s.addGroup);

  return (
    <div
      className="flex items-end gap-0.5 px-2 overflow-x-auto"
      style={{ backgroundColor: colors.bg.tertiary, borderBottom: `2px solid ${colors.border.default}` }}
      role="tablist"
    >
      {groups.map((group, i) => {
        const isActive = group.id === activeGroupId;
        return (
          <button
            key={group.id}
            role="tab"
            aria-selected={isActive}
            className="px-4 py-2 text-xs rounded-t-md shrink-0 transition-colors"
            style={{
              backgroundColor: isActive ? colors.bg.elevated : 'transparent',
              color: isActive ? colors.accent.primary : colors.text.muted,
              borderBottom: isActive ? `2px solid ${colors.accent.primary}` : '2px solid transparent',
            }}
            onClick={() => setActiveGroup(group.id)}
            title={group.cwd || group.label}
          >
            {group.isCustom && '🔧 '}{group.label}
          </button>
        );
      })}
      <button
        className="px-4 py-2 text-xs transition-colors"
        style={{ color: colors.text.dim }}
        onClick={() => addGroup(undefined, 'New Group')}
        title="New project tab"
      >
        +
      </button>
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/renderer/TabBar.test.tsx`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/renderer/components/TabBar.tsx tests/renderer/TabBar.test.tsx
git commit -m "feat: add TabBar component with project group tabs"
```

---

### Task 10: Sidebar Components (QuickLaunch + TerminalList + StatusBar)

**Files:**
- Create: `src/renderer/components/QuickLaunch.tsx`, `src/renderer/components/TerminalEntry.tsx`, `src/renderer/components/TerminalList.tsx`, `src/renderer/components/StatusBar.tsx`, `src/renderer/components/Sidebar.tsx`, `tests/renderer/Sidebar.test.tsx`

- [ ] **Step 1: Write failing tests**

```typescript
// tests/renderer/Sidebar.test.tsx
import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { Sidebar } from '../../src/renderer/components/Sidebar';
import { useStore } from '../../src/renderer/store';
import { TerminalStatus, DEFAULT_PRESETS } from '../../src/shared/types';

describe('Sidebar', () => {
  beforeEach(() => {
    useStore.setState({ ...useStore.getInitialState(), presets: DEFAULT_PRESETS });
  });

  it('renders quick launch preset buttons', () => {
    render(<Sidebar onSpawn={() => {}} />);
    expect(screen.getByText('Claude Code')).toBeTruthy();
    expect(screen.getByText('Resume Session')).toBeTruthy();
    expect(screen.getByText('Shell')).toBeTruthy();
  });

  it('renders terminal list for active group', () => {
    useStore.getState().addGroup('~/foo', 'foo');
    const gid = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(gid, {
      id: 't1', command: 'claude', cwd: '~/foo', status: TerminalStatus.RUNNING,
    });
    render(<Sidebar onSpawn={() => {}} />);
    expect(screen.getByText('claude')).toBeTruthy();
    expect(screen.getByText('RUNNING')).toBeTruthy();
  });

  it('filter narrows terminal list', () => {
    useStore.getState().addGroup('~/foo', 'foo');
    const gid = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(gid, {
      id: 't1', command: 'claude', cwd: '~/foo', status: TerminalStatus.RUNNING,
    });
    useStore.getState().addTerminal(gid, {
      id: 't2', command: 'npm run dev', cwd: '~/foo', status: TerminalStatus.RUNNING,
    });
    render(<Sidebar onSpawn={() => {}} />);
    fireEvent.change(screen.getByPlaceholderText('Filter terminals...'), { target: { value: 'npm' } });
    expect(screen.queryByText('claude')).toBeNull();
    expect(screen.getByText('npm run dev')).toBeTruthy();
  });

  it('shows terminal and external counts in status bar', () => {
    useStore.getState().addGroup('~/foo', 'foo');
    const gid = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(gid, {
      id: 't1', command: 'claude', cwd: '~/foo', status: TerminalStatus.RUNNING,
    });
    useStore.getState().addTerminal(gid, {
      id: 't2', command: 'vim', cwd: '~/foo', status: TerminalStatus.EXTERNAL, isExternal: true,
    });
    render(<Sidebar onSpawn={() => {}} />);
    expect(screen.getByText('2 terminals')).toBeTruthy();
    expect(screen.getByText('1 external')).toBeTruthy();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/renderer/Sidebar.test.tsx`
Expected: FAIL

- [ ] **Step 3: Implement QuickLaunch**

```typescript
// src/renderer/components/QuickLaunch.tsx
import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

interface QuickLaunchProps {
  onSpawn: (command: string, env?: Record<string, string>) => void;
}

export function QuickLaunch({ onSpawn }: QuickLaunchProps) {
  const presets = useStore((s) => s.presets);

  return (
    <div className="p-2.5 border-b" style={{ borderColor: colors.border.default }}>
      <div className="text-[9px] uppercase tracking-widest mb-1.5" style={{ color: colors.text.dim }}>
        Quick Launch
      </div>
      <div className="flex gap-1 flex-wrap">
        {presets.map((preset) => (
          <button
            key={preset.name}
            className="px-2 py-1 rounded text-[10px] border transition-colors hover:opacity-80"
            style={{
              backgroundColor: colors.bg.tertiary,
              borderColor: colors.border.default,
              color: preset.color,
            }}
            onClick={() => onSpawn(preset.command, preset.env)}
            title={preset.command}
          >
            {preset.name}
          </button>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Implement TerminalEntry**

```typescript
// src/renderer/components/TerminalEntry.tsx
import React from 'react';
import { useStore } from '../store';
import { TerminalStatus } from '../../shared/types';
import { colors } from '../theme/colors';

interface TerminalEntryProps {
  terminalId: string;
}

const statusConfig = {
  [TerminalStatus.ACTIVE]: { label: 'ACTIVE', ...colors.status.active },
  [TerminalStatus.RUNNING]: { label: 'RUNNING', ...colors.status.running },
  [TerminalStatus.EXITED]: { label: 'EXITED', ...colors.status.exited },
  [TerminalStatus.EXTERNAL]: { label: 'EXTERNAL', ...colors.status.external },
  [TerminalStatus.ATTACHING]: { label: 'ATTACHING', ...colors.status.attaching },
};

export function TerminalEntry({ terminalId }: TerminalEntryProps) {
  const terminal = useStore((s) => s.terminals[terminalId]);
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const setActiveTerminal = useStore((s) => s.setActiveTerminal);

  if (!terminal) return null;

  const isActive = terminalId === activeTerminalId;
  const isExternal = terminal.isExternal;
  const status = statusConfig[terminal.status];

  return (
    <button
      className="w-full text-left p-2 rounded-md mb-1 transition-colors"
      style={{
        backgroundColor: isActive ? colors.bg.elevated : 'transparent',
        borderLeft: isActive ? `3px solid ${colors.accent.primary}` : '3px solid transparent',
        opacity: isExternal ? 0.6 : 1,
      }}
      onClick={() => setActiveTerminal(terminalId)}
    >
      <div className="text-[11px]" style={{ color: isActive ? colors.text.primary : colors.text.secondary }}>
        {terminal.command.includes('claude') ? 'Claude Code' : 'Shell'}
      </div>
      <div className="text-[9px] mt-0.5 truncate" style={{ color: colors.text.dim }}>
        {terminal.command}
      </div>
      <div className="mt-1">
        <span
          className="text-[8px] px-1.5 py-0.5 rounded"
          style={{ backgroundColor: status.bg, color: status.text }}
        >
          {status.label}
        </span>
      </div>
    </button>
  );
}
```

- [ ] **Step 5: Implement TerminalList**

```typescript
// src/renderer/components/TerminalList.tsx
import React from 'react';
import { useStore } from '../store';
import { TerminalEntry } from './TerminalEntry';
import { colors } from '../theme/colors';

export function TerminalList() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const terminals = useStore((s) => s.terminals);
  const filterText = useStore((s) => s.filterText);
  const setFilterText = useStore((s) => s.setFilterText);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const terminalIds = activeGroup?.terminalIds ?? [];
  const filtered = filterText
    ? terminalIds.filter((id) => {
        const t = terminals[id];
        return t && t.command.toLowerCase().includes(filterText.toLowerCase());
      })
    : terminalIds;

  return (
    <div className="flex-1 overflow-y-auto px-1.5">
      <div className="px-1.5 mb-1.5 flex items-center justify-between">
        <span className="text-[9px] uppercase tracking-widest" style={{ color: colors.text.dim }}>
          Terminals ({terminalIds.length})
        </span>
      </div>
      <input
        type="text"
        placeholder="Filter terminals..."
        value={filterText}
        onChange={(e) => setFilterText(e.target.value)}
        className="w-full px-2 py-1 mb-2 rounded text-xs border outline-none"
        style={{
          backgroundColor: colors.bg.tertiary,
          borderColor: colors.border.default,
          color: colors.text.primary,
        }}
      />
      {filtered.map((id) => (
        <TerminalEntry key={id} terminalId={id} />
      ))}
    </div>
  );
}
```

- [ ] **Step 6: Implement StatusBar**

```typescript
// src/renderer/components/StatusBar.tsx
import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

export function StatusBar() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const terminals = useStore((s) => s.terminals);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const terminalIds = activeGroup?.terminalIds ?? [];
  const totalCount = terminalIds.length;
  const externalCount = terminalIds.filter((id) => terminals[id]?.isExternal).length;

  return (
    <div
      className="flex items-center justify-between px-2.5 py-1.5 text-[9px] border-t"
      style={{ color: colors.text.dim, borderColor: colors.border.default }}
    >
      <span>{totalCount} terminals</span>
      <span>{externalCount} external</span>
    </div>
  );
}
```

- [ ] **Step 7: Implement Sidebar (composition)**

```typescript
// src/renderer/components/Sidebar.tsx
import React from 'react';
import { QuickLaunch } from './QuickLaunch';
import { TerminalList } from './TerminalList';
import { StatusBar } from './StatusBar';
import { colors } from '../theme/colors';

interface SidebarProps {
  onSpawn: (command: string, env?: Record<string, string>) => void;
}

export function Sidebar({ onSpawn }: SidebarProps) {
  return (
    <div
      className="flex flex-col h-full"
      style={{ backgroundColor: colors.bg.secondary, borderRight: `1px solid ${colors.border.default}` }}
    >
      <QuickLaunch onSpawn={onSpawn} />
      <TerminalList />
      <StatusBar />
    </div>
  );
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `npx vitest run tests/renderer/Sidebar.test.tsx`
Expected: PASS (all 4 tests)

- [ ] **Step 9: Commit**

```bash
git add src/renderer/components/QuickLaunch.tsx src/renderer/components/TerminalEntry.tsx src/renderer/components/TerminalList.tsx src/renderer/components/StatusBar.tsx src/renderer/components/Sidebar.tsx tests/renderer/Sidebar.test.tsx
git commit -m "feat: add Sidebar with QuickLaunch, TerminalList, and StatusBar"
```

---

### Task 11: TerminalArea (Split Panes)

**Files:**
- Create: `src/renderer/components/TerminalArea.tsx`

- [ ] **Step 1: Implement TerminalArea with split pane support**

```typescript
// src/renderer/components/TerminalArea.tsx
import React from 'react';
import { useStore } from '../store';
import { TerminalPane } from './TerminalPane';
import { colors } from '../theme/colors';

export function TerminalArea() {
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const hasTerminals = activeGroup && activeGroup.terminalIds.length > 0;

  if (!hasTerminals || !activeTerminalId) {
    return (
      <div className="flex-1 flex items-center justify-center" style={{ backgroundColor: colors.bg.primary }}>
        <div className="text-center">
          <p style={{ color: colors.text.dim }}>No terminal open</p>
          <p className="text-xs mt-2" style={{ color: colors.text.dim }}>
            Use Quick Launch or press ⌘N
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden" style={{ backgroundColor: colors.bg.primary }}>
      <TerminalPane terminalId={activeTerminalId} />
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/renderer/components/TerminalArea.tsx
git commit -m "feat: add TerminalArea component"
```

---

### Task 12: Wire App Layout Together

**Files:**
- Modify: `src/renderer/App.tsx`

- [ ] **Step 1: Update App.tsx to compose all components**

```typescript
// src/renderer/App.tsx
import React, { useCallback, useEffect } from 'react';
import { TabBar } from './components/TabBar';
import { Sidebar } from './components/Sidebar';
import { TerminalArea } from './components/TerminalArea';
import { useStore } from './store';
import { usePty, useStateApi } from './hooks/usePty';
import { TerminalStatus } from '../shared/types';
import { colors } from './theme/colors';

export function App() {
  const pty = usePty();
  const stateApi = useStateApi();
  const addTerminal = useStore((s) => s.addTerminal);
  const findOrCreateGroup = useStore((s) => s.findOrCreateGroup);
  const setActiveTerminal = useStore((s) => s.setActiveTerminal);
  const updateTerminalStatus = useStore((s) => s.updateTerminalStatus);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const groups = useStore((s) => s.groups);

  // Load saved state on mount
  useEffect(() => {
    stateApi.load().then((data: any) => {
      if (data?.presets) useStore.getState().setPresets(data.presets);
      if (data?.settings) useStore.getState().setSettings(data.settings);
      if (data?.state?.groups) {
        // Restore groups only (terminals spawn fresh)
        for (const g of data.state.groups) {
          useStore.getState().addGroup(g.cwd, g.label);
        }
      }
    });
  }, []);

  // Listen for PTY exit events
  useEffect(() => {
    pty.onExit((id, code, signal) => {
      updateTerminalStatus(id, TerminalStatus.EXITED, code);
    });
  }, []);

  const handleSpawn = useCallback(async (command: string, env?: Record<string, string>) => {
    const activeGroup = groups.find((g) => g.id === activeGroupId);
    const cwd = activeGroup?.cwd || process.env.HOME || '/';
    const groupId = activeGroup?.id || findOrCreateGroup(cwd);

    const id = await pty.spawn({ cwd, command, env });

    addTerminal(groupId, {
      id,
      command,
      cwd,
      status: TerminalStatus.RUNNING,
    });
    setActiveTerminal(id);
  }, [activeGroupId, groups, pty, addTerminal, findOrCreateGroup, setActiveTerminal]);

  return (
    <div className="flex flex-col h-screen" style={{ backgroundColor: colors.bg.primary, color: colors.text.primary }}>
      {/* Title bar drag region */}
      <div className="h-8 flex items-center justify-between px-4 shrink-0"
        style={{ backgroundColor: colors.bg.tertiary, WebkitAppRegion: 'drag' } as React.CSSProperties}>
        <span className="text-[11px]" style={{ color: colors.text.muted }}>Dispatch</span>
        <div className="flex gap-2 text-[10px]" style={{ color: colors.text.dim, WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
          <span>⌘K Search</span>
          <span>⌘N New</span>
        </div>
      </div>

      {/* Tab bar */}
      <TabBar />

      {/* Main content */}
      <div className="flex flex-1 overflow-hidden">
        <div className="w-56 shrink-0">
          <Sidebar onSpawn={handleSpawn} />
        </div>
        <TerminalArea />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Verify full build**

Run: `npm run build`
Expected: Clean build

- [ ] **Step 3: Commit**

```bash
git add src/renderer/App.tsx
git commit -m "feat: wire App layout with TabBar, Sidebar, and TerminalArea"
```

---

### Task 13: Keyboard Shortcuts

**Files:**
- Create: `src/renderer/hooks/useShortcuts.ts`
- Modify: `src/renderer/App.tsx`

- [ ] **Step 1: Implement useShortcuts hook**

```typescript
// src/renderer/hooks/useShortcuts.ts
import { useEffect } from 'react';
import { useStore } from '../store';

interface ShortcutHandlers {
  onNewTerminal: () => void;
  onNewTab: () => void;
  onCloseTerminal: () => void;
  onOpenSearch: () => void;
  onOpenPalette: () => void;
}

export function useShortcuts(handlers: ShortcutHandlers) {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const setActiveGroup = useStore((s) => s.setActiveGroup);
  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const terminals = activeGroup?.terminalIds ?? [];
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const setActiveTerminal = useStore((s) => s.setActiveTerminal);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const meta = e.metaKey || e.ctrlKey;

      // Cmd+N: New terminal
      if (meta && e.key === 'n' && !e.shiftKey) {
        e.preventDefault();
        handlers.onNewTerminal();
        return;
      }

      // Cmd+T: New tab
      if (meta && e.key === 't') {
        e.preventDefault();
        handlers.onNewTab();
        return;
      }

      // Cmd+W: Close terminal
      if (meta && e.key === 'w') {
        e.preventDefault();
        handlers.onCloseTerminal();
        return;
      }

      // Cmd+K: Quick search
      if (meta && e.key === 'k') {
        e.preventDefault();
        handlers.onOpenSearch();
        return;
      }

      // Cmd+Shift+P: Command palette
      if (meta && e.shiftKey && e.key === 'p') {
        e.preventDefault();
        handlers.onOpenPalette();
        return;
      }

      // Cmd+1-9: Switch tab
      if (meta && e.key >= '1' && e.key <= '9') {
        e.preventDefault();
        const index = parseInt(e.key, 10) - 1;
        if (groups[index]) {
          setActiveGroup(groups[index].id);
        }
        return;
      }

      // Cmd+Shift+] or [: Next/prev tab
      if (meta && e.shiftKey && (e.key === ']' || e.key === '[')) {
        e.preventDefault();
        const currentIndex = groups.findIndex((g) => g.id === activeGroupId);
        const next = e.key === ']'
          ? (currentIndex + 1) % groups.length
          : (currentIndex - 1 + groups.length) % groups.length;
        if (groups[next]) setActiveGroup(groups[next].id);
        return;
      }

      // Ctrl+Tab: Cycle terminals in group
      if (e.ctrlKey && e.key === 'Tab') {
        e.preventDefault();
        if (terminals.length > 0) {
          const currentIndex = terminals.indexOf(activeTerminalId || '');
          const next = (currentIndex + 1) % terminals.length;
          setActiveTerminal(terminals[next]);
        }
        return;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [groups, activeGroupId, terminals, activeTerminalId, handlers]);
}
```

- [ ] **Step 2: Wire shortcuts into App.tsx**

Add to `App.tsx` inside the `App` component, before the return:

```typescript
const [searchOpen, setSearchOpen] = React.useState(false);
const [paletteOpen, setPaletteOpen] = React.useState(false);

const removeTerminal = useStore((s) => s.removeTerminal);
const addGroup = useStore((s) => s.addGroup);

useShortcuts({
  onNewTerminal: () => handleSpawn('$SHELL'),
  onNewTab: () => addGroup(undefined, 'New Group'),
  onCloseTerminal: () => {
    const id = useStore.getState().activeTerminalId;
    if (id) {
      pty.kill(id);
      removeTerminal(id);
    }
  },
  onOpenSearch: () => setSearchOpen(true),
  onOpenPalette: () => setPaletteOpen(true),
});
```

- [ ] **Step 3: Commit**

```bash
git add src/renderer/hooks/useShortcuts.ts src/renderer/App.tsx
git commit -m "feat: add keyboard shortcuts for navigation and terminal management"
```

---

### Task 14: Command Palette

**Files:**
- Create: `src/renderer/components/CommandPalette.tsx`, `tests/renderer/CommandPalette.test.tsx`

- [ ] **Step 1: Write failing test**

```typescript
// tests/renderer/CommandPalette.test.tsx
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { CommandPalette } from '../../src/renderer/components/CommandPalette';
import { useStore } from '../../src/renderer/store';
import { DEFAULT_PRESETS } from '../../src/shared/types';

describe('CommandPalette', () => {
  const onClose = vi.fn();
  const onSpawn = vi.fn();

  beforeEach(() => {
    useStore.setState({ ...useStore.getInitialState(), presets: DEFAULT_PRESETS });
    onClose.mockClear();
    onSpawn.mockClear();
  });

  it('renders all presets as options', () => {
    render(<CommandPalette open={true} onClose={onClose} onSpawn={onSpawn} />);
    expect(screen.getByText('Claude Code')).toBeTruthy();
    expect(screen.getByText('Resume Session')).toBeTruthy();
  });

  it('filters presets by search input', () => {
    render(<CommandPalette open={true} onClose={onClose} onSpawn={onSpawn} />);
    fireEvent.change(screen.getByPlaceholderText('Search presets and actions...'), { target: { value: 'resume' } });
    expect(screen.getByText('Resume Session')).toBeTruthy();
    expect(screen.queryByText('Shell')).toBeNull();
  });

  it('does not render when closed', () => {
    render(<CommandPalette open={false} onClose={onClose} onSpawn={onSpawn} />);
    expect(screen.queryByPlaceholderText('Search presets and actions...')).toBeNull();
  });

  it('closes on Escape', () => {
    render(<CommandPalette open={true} onClose={onClose} onSpawn={onSpawn} />);
    fireEvent.keyDown(screen.getByPlaceholderText('Search presets and actions...'), { key: 'Escape' });
    expect(onClose).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/renderer/CommandPalette.test.tsx`
Expected: FAIL

- [ ] **Step 3: Implement CommandPalette**

```typescript
// src/renderer/components/CommandPalette.tsx
import React, { useState, useRef, useEffect, useMemo } from 'react';
import Fuse from 'fuse.js';
import { useStore } from '../store';
import { colors } from '../theme/colors';
import type { Preset } from '../../shared/types';

interface CommandPaletteProps {
  open: boolean;
  onClose: () => void;
  onSpawn: (command: string, env?: Record<string, string>) => void;
}

export function CommandPalette({ open, onClose, onSpawn }: CommandPaletteProps) {
  const [query, setQuery] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const presets = useStore((s) => s.presets);

  const fuse = useMemo(() => new Fuse(presets, { keys: ['name', 'command'], threshold: 0.4 }), [presets]);

  const results: Preset[] = query
    ? fuse.search(query).map((r) => r.item)
    : presets;

  useEffect(() => {
    if (open) {
      setQuery('');
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [open]);

  if (!open) return null;

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      onClose();
    } else if (e.key === 'Enter' && results.length > 0) {
      onSpawn(results[0].command, results[0].env);
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center pt-24" onClick={onClose}>
      <div
        className="w-[500px] rounded-lg shadow-2xl border overflow-hidden"
        style={{ backgroundColor: colors.bg.tertiary, borderColor: colors.border.default }}
        onClick={(e) => e.stopPropagation()}
      >
        <input
          ref={inputRef}
          type="text"
          placeholder="Search presets and actions..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          className="w-full px-4 py-3 text-sm border-b outline-none"
          style={{
            backgroundColor: colors.bg.tertiary,
            borderColor: colors.border.default,
            color: colors.text.primary,
          }}
        />
        <div className="max-h-64 overflow-y-auto">
          {results.map((preset) => (
            <button
              key={preset.name}
              className="w-full px-4 py-2.5 flex items-center gap-3 text-left hover:opacity-80 transition-colors"
              style={{ backgroundColor: 'transparent' }}
              onClick={() => { onSpawn(preset.command, preset.env); onClose(); }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.bg.elevated)}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
            >
              <span className="w-2 h-2 rounded-full" style={{ backgroundColor: preset.color }} />
              <div>
                <div className="text-sm" style={{ color: colors.text.primary }}>{preset.name}</div>
                <div className="text-xs" style={{ color: colors.text.dim }}>{preset.command}</div>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/renderer/CommandPalette.test.tsx`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/renderer/components/CommandPalette.tsx tests/renderer/CommandPalette.test.tsx
git commit -m "feat: add CommandPalette with fuzzy search via fuse.js"
```

---

### Task 15: Quick Switcher (Cmd+K)

**Files:**
- Create: `src/renderer/components/QuickSwitcher.tsx`, `tests/renderer/QuickSwitcher.test.tsx`

- [ ] **Step 1: Write failing test**

```typescript
// tests/renderer/QuickSwitcher.test.tsx
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { QuickSwitcher } from '../../src/renderer/components/QuickSwitcher';
import { useStore } from '../../src/renderer/store';
import { TerminalStatus } from '../../src/shared/types';

describe('QuickSwitcher', () => {
  const onClose = vi.fn();

  beforeEach(() => {
    useStore.setState(useStore.getInitialState());
    onClose.mockClear();
  });

  it('shows groups and terminals in search results', () => {
    useStore.getState().addGroup('~/foo', 'foo');
    const gid = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(gid, {
      id: 't1', command: 'claude --resume', cwd: '~/foo', status: TerminalStatus.RUNNING,
    });
    render(<QuickSwitcher open={true} onClose={onClose} />);
    expect(screen.getByText('foo')).toBeTruthy();
    expect(screen.getByText('claude --resume')).toBeTruthy();
  });

  it('filters results by query', () => {
    useStore.getState().addGroup('~/foo', 'foo');
    useStore.getState().addGroup('~/bar', 'bar');
    render(<QuickSwitcher open={true} onClose={onClose} />);
    fireEvent.change(screen.getByPlaceholderText('Switch to...'), { target: { value: 'bar' } });
    expect(screen.queryByText('foo')).toBeNull();
    expect(screen.getByText('bar')).toBeTruthy();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/renderer/QuickSwitcher.test.tsx`
Expected: FAIL

- [ ] **Step 3: Implement QuickSwitcher**

```typescript
// src/renderer/components/QuickSwitcher.tsx
import React, { useState, useRef, useEffect, useMemo } from 'react';
import Fuse from 'fuse.js';
import { useStore } from '../store';
import { colors } from '../theme/colors';

interface QuickSwitcherProps {
  open: boolean;
  onClose: () => void;
}

interface SwitchItem {
  type: 'group' | 'terminal';
  id: string;
  label: string;
  sublabel?: string;
}

export function QuickSwitcher({ open, onClose }: QuickSwitcherProps) {
  const [query, setQuery] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const groups = useStore((s) => s.groups);
  const terminals = useStore((s) => s.terminals);
  const setActiveGroup = useStore((s) => s.setActiveGroup);
  const setActiveTerminal = useStore((s) => s.setActiveTerminal);

  const items: SwitchItem[] = useMemo(() => {
    const list: SwitchItem[] = [];
    for (const g of groups) {
      list.push({ type: 'group', id: g.id, label: g.label, sublabel: g.cwd });
      for (const tid of g.terminalIds) {
        const t = terminals[tid];
        if (t) list.push({ type: 'terminal', id: tid, label: t.command, sublabel: t.cwd });
      }
    }
    return list;
  }, [groups, terminals]);

  const fuse = useMemo(() => new Fuse(items, { keys: ['label', 'sublabel'], threshold: 0.4 }), [items]);

  const results = query ? fuse.search(query).map((r) => r.item) : items;

  useEffect(() => {
    if (open) {
      setQuery('');
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [open]);

  if (!open) return null;

  const handleSelect = (item: SwitchItem) => {
    if (item.type === 'group') {
      setActiveGroup(item.id);
    } else {
      setActiveTerminal(item.id);
      // Also switch to the group containing this terminal
      const group = groups.find((g) => g.terminalIds.includes(item.id));
      if (group) setActiveGroup(group.id);
    }
    onClose();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') onClose();
    else if (e.key === 'Enter' && results.length > 0) handleSelect(results[0]);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center pt-24" onClick={onClose}>
      <div
        className="w-[500px] rounded-lg shadow-2xl border overflow-hidden"
        style={{ backgroundColor: colors.bg.tertiary, borderColor: colors.border.default }}
        onClick={(e) => e.stopPropagation()}
      >
        <input
          ref={inputRef}
          type="text"
          placeholder="Switch to..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          className="w-full px-4 py-3 text-sm border-b outline-none"
          style={{
            backgroundColor: colors.bg.tertiary,
            borderColor: colors.border.default,
            color: colors.text.primary,
          }}
        />
        <div className="max-h-64 overflow-y-auto">
          {results.map((item) => (
            <button
              key={`${item.type}-${item.id}`}
              className="w-full px-4 py-2.5 flex items-center gap-3 text-left transition-colors"
              onClick={() => handleSelect(item)}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.bg.elevated)}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
            >
              <span className="text-[10px] uppercase w-14" style={{ color: colors.text.dim }}>
                {item.type === 'group' ? 'Project' : 'Term'}
              </span>
              <div>
                <div className="text-sm" style={{ color: colors.text.primary }}>{item.label}</div>
                {item.sublabel && (
                  <div className="text-xs" style={{ color: colors.text.dim }}>{item.sublabel}</div>
                )}
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/renderer/QuickSwitcher.test.tsx`
Expected: PASS

- [ ] **Step 5: Wire into App.tsx and commit**

Add `<CommandPalette>` and `<QuickSwitcher>` to `App.tsx` return, passing `searchOpen`/`paletteOpen` state and handlers.

```bash
git add src/renderer/components/QuickSwitcher.tsx tests/renderer/QuickSwitcher.test.tsx src/renderer/App.tsx
git commit -m "feat: add QuickSwitcher (Cmd+K) with fuzzy search"
```

---

### Task 16: Process Scanner

**Files:**
- Create: `src/main/process-scanner.ts`, `tests/main/process-scanner.test.ts`

- [ ] **Step 1: Write failing test**

```typescript
// tests/main/process-scanner.test.ts
import { describe, it, expect } from 'vitest';
import { ProcessScanner } from '../../src/main/process-scanner';

describe('ProcessScanner', () => {
  it('instantiates without error', () => {
    const scanner = new ProcessScanner();
    expect(scanner).toBeDefined();
  });

  it('scan returns an array', async () => {
    const scanner = new ProcessScanner();
    const results = await scanner.scan();
    expect(Array.isArray(results)).toBe(true);
  });

  it('results have pid, command, and cwd fields', async () => {
    const scanner = new ProcessScanner();
    const results = await scanner.scan();
    // We can't guarantee external terminals exist, but format should be correct
    for (const r of results) {
      expect(typeof r.pid).toBe('number');
      expect(typeof r.command).toBe('string');
      expect(typeof r.cwd).toBe('string');
    }
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/main/process-scanner.test.ts`
Expected: FAIL

- [ ] **Step 3: Implement ProcessScanner**

```typescript
// src/main/process-scanner.ts
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import os from 'os';

export interface ExternalTerminal {
  pid: number;
  command: string;
  cwd: string;
  emulator?: string;
}

const KNOWN_SHELLS = ['bash', 'zsh', 'fish', 'sh', 'dash'];
const KNOWN_EMULATORS = ['iTerm2', 'Terminal', 'gnome-terminal', 'alacritty', 'kitty', 'code'];

export class ProcessScanner {
  async scan(): Promise<ExternalTerminal[]> {
    if (process.platform === 'darwin') {
      return this.scanMac();
    } else if (process.platform === 'linux') {
      return this.scanLinux();
    }
    return [];
  }

  private scanMac(): ExternalTerminal[] {
    try {
      const uid = process.getuid?.() ?? 0;
      const output = execSync(`ps -eo pid,tty,comm -u ${uid}`, { encoding: 'utf-8', timeout: 5000 });
      const lines = output.trim().split('\n').slice(1);
      const results: ExternalTerminal[] = [];

      for (const line of lines) {
        const parts = line.trim().split(/\s+/);
        if (parts.length < 3) continue;
        const pid = parseInt(parts[0], 10);
        const tty = parts[1];
        const comm = parts.slice(2).join(' ');

        // Filter: must have a controlling terminal, must be a known shell
        if (tty === '??' || tty === '-') continue;
        const basename = path.basename(comm);
        if (!KNOWN_SHELLS.includes(basename)) continue;

        // Try to get CWD via lsof for this specific PID (fast for single PID)
        let cwd = '';
        try {
          const lsofOut = execSync(`lsof -p ${pid} -d cwd -Fn 2>/dev/null`, { encoding: 'utf-8', timeout: 2000 });
          const cwdLine = lsofOut.split('\n').find((l) => l.startsWith('n'));
          if (cwdLine) cwd = cwdLine.slice(1);
        } catch {
          cwd = os.homedir();
        }

        results.push({ pid, command: basename, cwd });
      }

      return results;
    } catch {
      return [];
    }
  }

  private scanLinux(): ExternalTerminal[] {
    try {
      const uid = process.getuid?.() ?? 0;
      const procDirs = fs.readdirSync('/proc').filter((d) => /^\d+$/.test(d));
      const results: ExternalTerminal[] = [];

      for (const pidStr of procDirs) {
        try {
          const statPath = `/proc/${pidStr}/stat`;
          const stat = fs.readFileSync(statPath, 'utf-8');
          // Check UID
          const statusPath = `/proc/${pidStr}/status`;
          const status = fs.readFileSync(statusPath, 'utf-8');
          const uidLine = status.split('\n').find((l) => l.startsWith('Uid:'));
          if (!uidLine) continue;
          const processUid = parseInt(uidLine.split('\t')[1], 10);
          if (processUid !== uid) continue;

          // Check if has controlling terminal (tty_nr != 0)
          const statParts = stat.split(' ');
          const ttyNr = parseInt(statParts[6], 10);
          if (ttyNr === 0) continue;

          // Get command name
          const comm = fs.readFileSync(`/proc/${pidStr}/comm`, 'utf-8').trim();
          if (!KNOWN_SHELLS.includes(comm)) continue;

          // Get CWD
          const cwd = fs.readlinkSync(`/proc/${pidStr}/cwd`);

          results.push({ pid: parseInt(pidStr, 10), command: comm, cwd });
        } catch {
          continue;
        }
      }

      return results;
    } catch {
      return [];
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/main/process-scanner.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/main/process-scanner.ts tests/main/process-scanner.test.ts
git commit -m "feat: add ProcessScanner for external terminal detection"
```

---

### Task 17: tmux Integration

**Files:**
- Create: `src/main/tmux.ts`, `tests/main/tmux.test.ts`

- [ ] **Step 1: Write failing test**

```typescript
// tests/main/tmux.test.ts
import { describe, it, expect } from 'vitest';
import { TmuxHelper } from '../../src/main/tmux';

describe('TmuxHelper', () => {
  it('isAvailable returns a boolean', () => {
    const result = TmuxHelper.isAvailable();
    expect(typeof result).toBe('boolean');
  });

  it('listSessions returns an array', () => {
    const sessions = TmuxHelper.listSessions();
    expect(Array.isArray(sessions)).toBe(true);
  });

  it('getAttachCommand returns a valid command string', () => {
    const cmd = TmuxHelper.getAttachCommand('my-session');
    expect(cmd).toBe('tmux attach-session -t my-session');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/main/tmux.test.ts`
Expected: FAIL

- [ ] **Step 3: Implement TmuxHelper**

```typescript
// src/main/tmux.ts
import { execSync } from 'child_process';

export interface TmuxSession {
  name: string;
  windows: number;
  attached: boolean;
}

export class TmuxHelper {
  static isAvailable(): boolean {
    try {
      execSync('which tmux', { encoding: 'utf-8', timeout: 2000 });
      return true;
    } catch {
      return false;
    }
  }

  static listSessions(): TmuxSession[] {
    if (!this.isAvailable()) return [];
    try {
      const output = execSync('tmux list-sessions -F "#{session_name}:#{session_windows}:#{session_attached}"', {
        encoding: 'utf-8',
        timeout: 3000,
      });
      return output.trim().split('\n').filter(Boolean).map((line) => {
        const [name, windows, attached] = line.split(':');
        return { name, windows: parseInt(windows, 10), attached: attached === '1' };
      });
    } catch {
      return [];
    }
  }

  static getAttachCommand(sessionName: string): string {
    return `tmux attach-session -t ${sessionName}`;
  }

  static findSessionForPid(pid: number): string | null {
    if (!this.isAvailable()) return null;
    try {
      const output = execSync(
        `tmux list-panes -a -F "#{pane_pid}:#{session_name}" 2>/dev/null`,
        { encoding: 'utf-8', timeout: 3000 }
      );
      for (const line of output.trim().split('\n')) {
        const [panePid, sessionName] = line.split(':');
        if (parseInt(panePid, 10) === pid) return sessionName;
      }
      return null;
    } catch {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run tests/main/tmux.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/main/tmux.ts tests/main/tmux.test.ts
git commit -m "feat: add TmuxHelper for session detection and attach commands"
```

---

### Task 18: Wire Scanner + tmux into IPC

**Files:**
- Modify: `src/main/ipc.ts`, `src/main/index.ts`

- [ ] **Step 1: Add scanner IPC handlers and background interval**

Add to `src/main/ipc.ts`:

```typescript
import { ProcessScanner } from './process-scanner';
import { TmuxHelper } from './tmux';

// Add to registerIpc function:
export function registerIpc(ptyManager: PtyManager, store: SessionStore): void {
  // ... existing handlers ...

  const scanner = new ProcessScanner();

  // Start background scanning after 3-second delay
  let scanInterval: NodeJS.Timeout | null = null;

  const startScanning = async () => {
    const settings = await store.loadSettings();
    const interval = settings.scanInterval || 10000;

    scanInterval = setInterval(async () => {
      const results = await scanner.scan();
      // Enrich with tmux session info
      const enriched = results.map((r) => ({
        ...r,
        tmuxSession: TmuxHelper.findSessionForPid(r.pid),
      }));
      const win = BrowserWindow.getAllWindows()[0];
      win?.webContents.send(IPC.SCANNER_RESULTS, enriched);
    }, interval);
  };

  setTimeout(startScanning, 3000);

  ipcMain.handle(IPC.SCANNER_ATTACH, async (_event, pid: number) => {
    const session = TmuxHelper.findSessionForPid(pid);
    if (session) {
      const cmd = TmuxHelper.getAttachCommand(session);
      const id = ptyManager.spawn({ cwd: process.env.HOME || '/', command: cmd });
      return { id, attached: true };
    }
    return { attached: false };
  });
}
```

- [ ] **Step 2: Verify build**

Run: `npm run build`
Expected: Clean build

- [ ] **Step 3: Commit**

```bash
git add src/main/ipc.ts
git commit -m "feat: wire process scanner and tmux attach into IPC"
```

---

### Task 19: Session Persistence (Auto-save & Restore)

**Files:**
- Modify: `src/renderer/App.tsx`

- [ ] **Step 1: Add debounced auto-save**

Add to `App.tsx`:

```typescript
// Auto-save state on changes (debounced 2 seconds)
const saveTimeoutRef = React.useRef<NodeJS.Timeout | null>(null);

useEffect(() => {
  const unsub = useStore.subscribe((state) => {
    if (saveTimeoutRef.current) clearTimeout(saveTimeoutRef.current);
    saveTimeoutRef.current = setTimeout(() => {
      stateApi.save({
        groups: state.groups,
        activeGroupId: state.activeGroupId,
        activeTerminalId: null,
        windowBounds: { x: 0, y: 0, width: 1200, height: 800 },
        sidebarWidth: state.sidebarWidth,
      });
    }, 2000);
  });
  return () => unsub();
}, [stateApi]);
```

- [ ] **Step 2: Verify build**

Run: `npm run build`
Expected: Clean build

- [ ] **Step 3: Commit**

```bash
git add src/renderer/App.tsx
git commit -m "feat: add debounced auto-save of layout state"
```

---

### Task 20: Electron Builder Config & Packaging

**Files:**
- Create: `electron-builder.yml`

- [ ] **Step 1: Create electron-builder config**

```yaml
# electron-builder.yml
appId: com.dispatch.app
productName: Dispatch
directories:
  output: release
  buildResources: build
files:
  - dist/**/*
  - package.json
mac:
  category: public.app-category.developer-tools
  target:
    - dmg
    - zip
  hardenedRuntime: true
linux:
  category: Development
  target:
    - AppImage
    - deb
  maintainer: dispatch
```

- [ ] **Step 2: Add build script to package.json**

Add to scripts:
```json
"package": "npm run build && electron-builder"
```

- [ ] **Step 3: Verify packaging config is valid**

Run: `npx electron-builder --help` (just verify it's installed)
Expected: Help output

- [ ] **Step 4: Commit**

```bash
git add electron-builder.yml package.json
git commit -m "feat: add electron-builder config for Mac DMG and Linux AppImage"
```

---

### Task 21: Vitest Config & Test Runner Setup

**Files:**
- Create: `vitest.config.ts`

- [ ] **Step 1: Create vitest config**

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    globals: true,
    environment: 'happy-dom',
    include: ['tests/**/*.test.{ts,tsx}'],
    alias: {
      '@shared': path.resolve(__dirname, 'src/shared'),
      '@main': path.resolve(__dirname, 'src/main'),
      '@renderer': path.resolve(__dirname, 'src/renderer'),
    },
  },
});
```

- [ ] **Step 2: Run full test suite**

Run: `npm test -- --run`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add vitest.config.ts
git commit -m "feat: add vitest config with happy-dom for renderer tests"
```

---

### Task 22: Integration Smoke Test

**Files:**
- None (manual verification)

- [ ] **Step 1: Full build and launch**

```bash
npm run build && npm start
```

Expected: Dispatch window opens with dark theme, tab bar, sidebar with quick launch buttons, and "No terminal open" placeholder.

- [ ] **Step 2: Verify terminal spawning works**

Click a Quick Launch button. Expected: xterm.js terminal appears with the command running.

- [ ] **Step 3: Verify keyboard shortcuts**

Test `Cmd+N` (new terminal), `Cmd+K` (switcher), `Cmd+Shift+P` (palette), `Cmd+W` (close).

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: integration verification complete"
```
