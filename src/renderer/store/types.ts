import type { TerminalEntry, ProjectGroup, Preset, Settings, Template, Task, Note, VaultEntry } from '../../shared/types';
export type { SplitDirection, SplitLeaf, SplitBranch, SplitNode } from '../../shared/types';
import type { SplitDirection, SplitNode } from '../../shared/types';

export type TerminalActivityStatus = 'idle' | 'running' | 'success' | 'error' | 'waiting';

export interface ResumeSession {
  sessionName: string;
  cwd: string;
  folderName: string;
  selected: boolean;
}

export interface StoreState {
  groups: ProjectGroup[];
  terminals: Record<string, TerminalEntry>;
  activeGroupId: string | null;
  activeTerminalId: string | null;
  zenMode: boolean;
  presets: Preset[];
  settings: Settings;
  sidebarWidth: number;
  filterText: string;
  settingsOpen: boolean;
  tmuxAvailable: boolean;
  terminalStatuses: Record<string, TerminalActivityStatus>;
  templates: Template[];
  resumeSessions: ResumeSession[] | null;
  projectTasks: Task[];
  projectNotes: Note[];
  projectVault: VaultEntry[];
  activePanel: 'tasks' | 'notes' | 'vault';
  editingNoteId: string | null;
}

export interface StoreActions {
  addGroup: (cwd: string | undefined, label: string) => void;
  removeGroup: (id: string) => void;
  setActiveGroup: (id: string) => void;
  reorderGroups: (fromIndex: number, toIndex: number) => void;
  findOrCreateGroup: (cwd: string) => string;
  addTerminal: (groupId: string, terminal: TerminalEntry) => void;
  removeTerminal: (id: string) => void;
  renameTerminal: (id: string, label: string) => void;
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
  setTerminalStatus: (id: string, status: TerminalActivityStatus) => void;
  setTemplates: (templates: Template[]) => void;
  setResumeSessions: (sessions: ResumeSession[] | null) => void;
  toggleResumeSession: (sessionName: string) => void;
  getGroupSplitLayout: (groupId: string) => SplitNode | null;
  setGroupSplitLayout: (groupId: string, layout: SplitNode | null) => void;
  setProjectTasks: (tasks: Task[]) => void;
  setProjectNotes: (notes: Note[]) => void;
  setProjectVault: (entries: VaultEntry[]) => void;
  setActivePanel: (panel: 'tasks' | 'notes' | 'vault') => void;
  setEditingNoteId: (id: string | null) => void;
}
