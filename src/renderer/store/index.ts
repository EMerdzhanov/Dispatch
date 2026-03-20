import { create } from 'zustand';
import { TerminalStatus, DEFAULT_PRESETS, DEFAULT_SETTINGS } from '../../shared/types';
import type { TerminalEntry } from '../../shared/types';
import type { SplitNode } from '../../shared/types';
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
  zenMode: false,
  presets: DEFAULT_PRESETS,
  settings: DEFAULT_SETTINGS,
  sidebarWidth: 220,
  filterText: '',
  settingsOpen: false,
  tmuxAvailable: false,
  terminalStatuses: {},
  templates: [],
  resumeSessions: null,
  projectTasks: [],
  projectNotes: [],
  projectVault: [],
  activePanel: 'tasks' as const,
  editingNoteId: null,
  browserTabs: {},
  activeBrowserTabId: null,
  consoleMessages: {},
  pipeToTerminal: false,
  lastBrowserUrl: null,
};

export const useStore = create<StoreState & StoreActions>()((set, get) => ({
  ...initialState,

  addGroup: (cwd, label) => {
    const id = genId();
    set((s) => ({
      groups: [...s.groups, { id, label, cwd: cwd || undefined, isCustom: !cwd, terminalIds: [], browserTabIds: [] }],
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
      groups: [...s.groups, { id, label, cwd, isCustom: false, terminalIds: [], browserTabIds: [] }],
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

  renameTerminal: (id, label) => {
    set((s) => ({
      terminals: {
        ...s.terminals,
        [id]: s.terminals[id] ? { ...s.terminals[id], label } : s.terminals[id],
      },
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
      return { activeTerminalId: id, terminals: newTerminals, activeBrowserTabId: null };
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
    const { activeTerminalId, activeGroupId, groups } = get();
    if (!activeTerminalId || !activeGroupId) return;
    const group = groups.find((g) => g.id === activeGroupId);
    if (!group) return;
    const currentLayout = group.splitLayout;

    if (!currentLayout) {
      set((s) => ({
        groups: s.groups.map((g) => g.id === activeGroupId ? {
          ...g,
          splitLayout: {
            type: 'branch' as const,
            direction,
            children: [
              { type: 'leaf' as const, terminalId: activeTerminalId },
              { type: 'leaf' as const, terminalId: '' }, // placeholder
            ] as [SplitNode, SplitNode],
            ratio: 0.5,
          },
        } : g),
      }));
    }
  },

  setSplitLayout: (layout) => {
    const { activeGroupId } = get();
    if (!activeGroupId) return;
    get().setGroupSplitLayout(activeGroupId, layout);
  },

  updateSplitRatio: (path, ratio) => {
    set((s) => {
      const group = s.groups.find((g) => g.id === s.activeGroupId);
      if (!group?.splitLayout || group.splitLayout.type !== 'branch') return s;
      const updated = JSON.parse(JSON.stringify(group.splitLayout));
      let node = updated;
      for (const idx of path) {
        if (node.type === 'branch' && node.children[idx]) {
          node = node.children[idx];
        }
      }
      if (node.type === 'branch') node.ratio = ratio;
      return {
        groups: s.groups.map((g) => g.id === s.activeGroupId ? { ...g, splitLayout: updated } : g),
      };
    });
  },

  toggleZenMode: () => set((s) => ({ zenMode: !s.zenMode })),
  setSettingsOpen: (open) => set({ settingsOpen: open }),
  setTmuxAvailable: (available) => set({ tmuxAvailable: available }),

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

  setProjectTasks: (tasks) => set({ projectTasks: tasks }),
  setProjectNotes: (notes) => set({ projectNotes: notes }),
  setProjectVault: (entries) => set({ projectVault: entries }),
  setActivePanel: (panel) => set({ activePanel: panel }),
  setEditingNoteId: (id) => set({ editingNoteId: id }),

  addBrowserTab: (groupId, tab) => set((s) => ({
    browserTabs: { ...s.browserTabs, [tab.id]: tab },
    groups: s.groups.map((g) => g.id === groupId
      ? { ...g, browserTabIds: [...(g.browserTabIds || []), tab.id] }
      : g),
    activeBrowserTabId: tab.id,
  })),

  removeBrowserTab: (groupId, tabId) => {
    const tab = get().browserTabs[tabId];
    // Save URL for "reopen last browser" and clear detected port
    if (tab) {
      try {
        const port = new URL(tab.url).port;
        if (port) (window as any).dispatch?.browser?.clearPort(port);
      } catch {}
    }
    set((s) => ({
      lastBrowserUrl: tab?.url || s.lastBrowserUrl,
      browserTabs: Object.fromEntries(Object.entries(s.browserTabs).filter(([k]) => k !== tabId)),
      groups: s.groups.map((g) => g.id === groupId
        ? { ...g, browserTabIds: (g.browserTabIds || []).filter((id) => id !== tabId) }
        : g),
      activeBrowserTabId: s.activeBrowserTabId === tabId ? null : s.activeBrowserTabId,
      consoleMessages: Object.fromEntries(Object.entries(s.consoleMessages).filter(([k]) => k !== tabId)),
    }));
  },

  setActiveBrowserTab: (tabId) => set({ activeBrowserTabId: tabId }),

  addConsoleMessage: (tabId, message) => set((s) => {
    const existing = s.consoleMessages[tabId] || [];
    const updated = [...existing, message].slice(-500);
    return { consoleMessages: { ...s.consoleMessages, [tabId]: updated } };
  }),

  clearConsoleMessages: (tabId) => set((s) => ({
    consoleMessages: { ...s.consoleMessages, [tabId]: [] },
  })),

  togglePipeToTerminal: () => set((s) => ({ pipeToTerminal: !s.pipeToTerminal })),
}));

// Expose getInitialState for test resets
(useStore as any).getInitialState = () => initialState;
