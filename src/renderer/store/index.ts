import { create } from 'zustand';
import { TerminalStatus, DEFAULT_PRESETS, DEFAULT_SETTINGS } from '../../shared/types';
import type { TerminalEntry } from '../../shared/types';
import type { StoreState, StoreActions, SplitLeaf } from './types';

const genId = () =>
  typeof crypto !== 'undefined' && crypto.randomUUID
    ? crypto.randomUUID()
    : Math.random().toString(36).slice(2);

const initialState: StoreState = {
  groups: [],
  terminals: {},
  activeGroupId: null,
  activeTerminalId: null,
  splitLayout: null,
  zenMode: false,
  presets: DEFAULT_PRESETS,
  settings: DEFAULT_SETTINGS,
  sidebarWidth: 220,
  filterText: '',
  settingsOpen: false,
  tmuxAvailable: false,
};

export const useStore = create<StoreState & StoreActions>()((set, get) => ({
  ...initialState,

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
      if (s.activeTerminalId && newTerminals[s.activeTerminalId]) {
        const prev = newTerminals[s.activeTerminalId];
        if (prev.status === TerminalStatus.ACTIVE) {
          newTerminals[s.activeTerminalId] = { ...prev, status: TerminalStatus.RUNNING };
        }
      }
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

  splitTerminal: (direction) => {
    const { activeTerminalId, splitLayout } = get();
    if (!activeTerminalId) return;
    if (!splitLayout) {
      set({
        splitLayout: {
          type: 'branch',
          direction,
          children: [
            { type: 'leaf', terminalId: activeTerminalId },
            { type: 'leaf', terminalId: '' }, // placeholder — caller fills in after spawning new terminal
          ],
          ratio: 0.5,
        },
      });
    }
  },

  setSplitLayout: (layout) => set({ splitLayout: layout }),

  updateSplitRatio: (path, ratio) => {
    set((s) => {
      if (!s.splitLayout || s.splitLayout.type !== 'branch') return s;
      const updated = JSON.parse(JSON.stringify(s.splitLayout));
      let node = updated;
      for (const idx of path) {
        if (node.type === 'branch' && node.children[idx]) {
          node = node.children[idx];
        }
      }
      if (node.type === 'branch') node.ratio = ratio;
      return { splitLayout: updated };
    });
  },

  toggleZenMode: () => set((s) => ({ zenMode: !s.zenMode })),
  setSettingsOpen: (open) => set({ settingsOpen: open }),
  setTmuxAvailable: (available) => set({ tmuxAvailable: available }),
}));

// Expose getInitialState for test resets
(useStore as any).getInitialState = () => initialState;
