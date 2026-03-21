export type SplitDirection = 'horizontal' | 'vertical';

export interface SplitLeaf {
  type: 'leaf';
  terminalId: string;
}

export interface SplitBranch {
  type: 'branch';
  direction: SplitDirection;
  children: [SplitNode, SplitNode];
  ratio: number;
}

export type SplitNode = SplitLeaf | SplitBranch;

export interface TemplateLeaf {
  type: 'leaf';
  command: string;
}

export interface TemplateBranch {
  type: 'branch';
  direction: SplitDirection;
  ratio: number;
  children: [TemplateNode, TemplateNode];
}

export type TemplateNode = TemplateLeaf | TemplateBranch;

export interface Template {
  name: string;
  cwd: string;
  splitLayout: TemplateNode | null;
}

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
  label?: string;       // custom name (e.g. "Security", "QA")
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
  splitLayout?: SplitNode | null;
  browserTabIds: string[];
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
  noTmux?: boolean; // bypass tmux (used in tests)
}

export interface Settings {
  shell: string;
  fontFamily: string;
  fontSize: number;
  lineHeight: number;
  scanInterval: number;
  keybindings: Record<string, string>;
  notificationsEnabled: boolean;
  soundEnabled: boolean;
  screenshotFolder: string;
}

export const DEFAULT_SETTINGS: Settings = {
  shell: typeof process !== 'undefined' && process.env?.SHELL ? process.env.SHELL : '/bin/sh',
  fontFamily: 'monospace',
  fontSize: 13,
  lineHeight: 1.2,
  scanInterval: 10000,
  keybindings: {},
  notificationsEnabled: true,
  soundEnabled: true,
  screenshotFolder: '',
};

export const DEFAULT_PRESETS: Preset[] = [
  { name: 'Claude Code', command: 'claude', color: '#0f3460', icon: 'brain' },
  { name: 'Resume Session', command: 'claude --resume', color: '#e94560', icon: 'rotate-ccw' },
  { name: 'Skip Permissions', command: 'claude --dangerously-skip-permissions', color: '#f5a623', icon: 'zap' },
  { name: 'Shell', command: '$SHELL', color: '#888888', icon: 'terminal', env: {} },
];

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
