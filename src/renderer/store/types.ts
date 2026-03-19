import type { TerminalEntry, ProjectGroup, Preset, Settings } from '../../shared/types';

export type SplitDirection = 'horizontal' | 'vertical';

export interface SplitLeaf {
  type: 'leaf';
  terminalId: string;
}

export interface SplitBranch {
  type: 'branch';
  direction: SplitDirection;
  children: SplitNode[];
  ratio: number;
}

export type SplitNode = SplitLeaf | SplitBranch;

export interface StoreState {
  groups: ProjectGroup[];
  terminals: Record<string, TerminalEntry>;
  activeGroupId: string | null;
  activeTerminalId: string | null;
  splitLayout: SplitNode | null;
  zenMode: boolean;
  presets: Preset[];
  settings: Settings;
  sidebarWidth: number;
  filterText: string;
  settingsOpen: boolean;
  tmuxAvailable: boolean;
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
  splitTerminal: (direction: SplitDirection) => void;
  setSplitLayout: (layout: SplitNode | null) => void;
  updateSplitRatio: (path: number[], ratio: number) => void;
  toggleZenMode: () => void;
  setSettingsOpen: (open: boolean) => void;
  setTmuxAvailable: (available: boolean) => void;
}
