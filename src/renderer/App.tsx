import React, { useCallback, useEffect } from 'react';
import { TabBar } from './components/TabBar';
import { Sidebar } from './components/Sidebar';
import { TerminalArea } from './components/TerminalArea';
import { CommandPalette } from './components/CommandPalette';
import { QuickSwitcher } from './components/QuickSwitcher';
import { SettingsPanel } from './components/SettingsPanel';
import { useStore } from './store';
import { usePty, useStateApi, useDialogApi } from './hooks/usePty';
import { useShortcuts } from './hooks/useShortcuts';
import { TerminalStatus } from '../shared/types';
import type { SplitNode, SplitDirection } from '../shared/types';

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

export function App() {
  const pty = usePty();
  const stateApi = useStateApi();
  const dialogApi = useDialogApi();
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
        for (const g of data.state.groups) {
          useStore.getState().addGroup(g.cwd, g.label);
        }
      }
    });
  }, []);

  // Auto-save state on changes (debounced 2 seconds)
  const saveTimeoutRef = React.useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    const unsub = useStore.subscribe((state) => {
      if (saveTimeoutRef.current) clearTimeout(saveTimeoutRef.current);
      saveTimeoutRef.current = setTimeout(() => {
        stateApi.save({
          groups: state.groups.map((g) => ({
            ...g,
            savedTerminals: g.terminalIds.map((tid) => {
              const t = state.terminals[tid];
              return t ? { command: t.command, cwd: t.cwd } : null;
            }).filter(Boolean),
          })),
          activeGroupId: state.activeGroupId,
          activeTerminalId: null,
          sidebarWidth: state.sidebarWidth,
        });
      }, 2000);
    });
    return () => unsub();
  }, [stateApi]);

  // Listen for PTY exit events
  useEffect(() => {
    const cleanup = pty.onExit((id, code, _signal) => {
      updateTerminalStatus(id, TerminalStatus.EXITED, code);
    });
    return cleanup;
  }, []);

  const [homedir, setHomedir] = React.useState('/');
  useEffect(() => {
    window.dispatch?.app?.getHomedir().then((h: string) => setHomedir(h));
  }, []);

  const handleSpawn = useCallback(async (command: string, env?: Record<string, string>) => {
    const activeGroup = groups.find((g) => g.id === activeGroupId);
    const cwd = activeGroup?.cwd || homedir;
    const groupId = activeGroup?.id || findOrCreateGroup(cwd);

    const id = await pty.spawn({ cwd, command, env });

    addTerminal(groupId, {
      id,
      command,
      cwd,
      status: TerminalStatus.RUNNING,
    });
    setActiveTerminal(id);
  }, [activeGroupId, groups, pty, addTerminal, findOrCreateGroup, setActiveTerminal, homedir]);

  const handleSpawnInCwd = useCallback(async (cwd: string, command?: string) => {
    const cmd = command || '$SHELL';
    const groupId = findOrCreateGroup(cwd);

    const id = await pty.spawn({ cwd, command: cmd });

    addTerminal(groupId, {
      id,
      command: cmd,
      cwd,
      status: TerminalStatus.RUNNING,
    });
    useStore.getState().setActiveGroup(groupId);
    setActiveTerminal(id);
  }, [pty, addTerminal, findOrCreateGroup, setActiveTerminal]);

  // Open a folder via the system dialog, create a tab, and auto-spawn a shell
  const handleOpenFolder = useCallback(async () => {
    const folderPath = await dialogApi.openFolder();
    if (!folderPath) return;

    // findOrCreateGroup returns the group ID (and creates the group if needed)
    const groupId = useStore.getState().findOrCreateGroup(folderPath);
    useStore.getState().setActiveGroup(groupId);

    const id = await pty.spawn({ cwd: folderPath, command: '$SHELL' });
    addTerminal(groupId, {
      id,
      command: '$SHELL',
      cwd: folderPath,
      status: TerminalStatus.RUNNING,
    });
    setActiveTerminal(id);
  }, [dialogApi, pty, addTerminal, setActiveTerminal]);

  const [searchOpen, setSearchOpen] = React.useState(false);
  const [paletteOpen, setPaletteOpen] = React.useState(false);

  useEffect(() => {
    (window as any).dispatch?.tmux?.isAvailable().then((available: boolean) => {
      useStore.getState().setTmuxAvailable(available);
    });
  }, []);

  const removeTerminal = useStore((s) => s.removeTerminal);
  const addGroup = useStore((s) => s.addGroup);
  const toggleZenMode = useStore((s) => s.toggleZenMode);
  const setSettingsOpen = useStore((s) => s.setSettingsOpen);
  const settingsOpen = useStore((s) => s.settingsOpen);

  useShortcuts({
    onNewTerminal: () => handleSpawn('$SHELL'),
    onNewTab: () => handleOpenFolder(),
    onCloseTerminal: () => {
      const state = useStore.getState();
      const id = state.activeTerminalId;
      if (!id) return;

      const group = state.groups.find((g) => g.id === state.activeGroupId);
      if (!group) return;

      pty.kill(id);
      removeTerminal(id);

      // Update split tree
      if (group.splitLayout) {
        const newLayout = removeLeafFromTree(group.splitLayout, id);
        state.setGroupSplitLayout(group.id, newLayout);
      }

      // Select another terminal
      const remaining = group.terminalIds.filter((t) => t !== id);
      if (remaining.length > 0) {
        state.setActiveTerminal(remaining[0]);
      }
    },
    onOpenSearch: () => setSearchOpen(true),
    onOpenPalette: () => setPaletteOpen(true),
    onSplitHorizontal: async () => {
      const state = useStore.getState();
      const group = state.groups.find((g) => g.id === state.activeGroupId);
      if (!group || !state.activeTerminalId) return;

      const cwd = group.cwd || homedir;
      const newId = await pty.spawn({ cwd, command: '$SHELL' });
      state.addTerminal(group.id, { id: newId, command: '$SHELL', cwd, status: TerminalStatus.RUNNING });

      const currentLayout = group.splitLayout;
      if (!currentLayout) {
        state.setGroupSplitLayout(group.id, {
          type: 'branch',
          direction: 'horizontal',
          ratio: 0.5,
          children: [
            { type: 'leaf', terminalId: state.activeTerminalId },
            { type: 'leaf', terminalId: newId },
          ],
        });
      } else {
        const newLayout = splitLeafInTree(currentLayout, state.activeTerminalId, newId, 'horizontal');
        state.setGroupSplitLayout(group.id, newLayout);
      }
    },
    onSplitVertical: async () => {
      const state = useStore.getState();
      const group = state.groups.find((g) => g.id === state.activeGroupId);
      if (!group || !state.activeTerminalId) return;

      const cwd = group.cwd || homedir;
      const newId = await pty.spawn({ cwd, command: '$SHELL' });
      state.addTerminal(group.id, { id: newId, command: '$SHELL', cwd, status: TerminalStatus.RUNNING });

      const currentLayout = group.splitLayout;
      if (!currentLayout) {
        state.setGroupSplitLayout(group.id, {
          type: 'branch',
          direction: 'vertical',
          ratio: 0.5,
          children: [
            { type: 'leaf', terminalId: state.activeTerminalId },
            { type: 'leaf', terminalId: newId },
          ],
        });
      } else {
        const newLayout = splitLeafInTree(currentLayout, state.activeTerminalId, newId, 'vertical');
        state.setGroupSplitLayout(group.id, newLayout);
      }
    },
    onToggleZenMode: () => toggleZenMode(),
    onOpenSettings: () => setSettingsOpen(true),
    onMovePaneFocus: (_dir) => { /* pane focus navigation — future enhancement */ },
  });

  const hasGroups = groups.length > 0;

  return (
    <div className="d-app">
      {/* Title bar drag region */}
      <div className="d-titlebar">
        {/* Left: keyboard hints */}
        <div className="d-titlebar__hints">
          <span>⌘K Search</span>
          <span>⌘N New</span>
        </div>
        {/* Center: app name */}
        <span className="d-titlebar__title">Dispatch</span>
      </div>

      {/* Tab bar */}
      <TabBar onSpawnInCwd={handleSpawnInCwd} onOpenFolder={handleOpenFolder} />

      {/* Main content */}
      {hasGroups ? (
        <div className="d-main">
          <Sidebar onSpawn={handleSpawn} onSpawnInCwd={handleSpawnInCwd} />
          <TerminalArea onSpawnInCwd={handleSpawnInCwd} />
        </div>
      ) : (
        <div className="d-welcome">
          <h1 className="d-welcome__title">Welcome to Dispatch</h1>
          <p className="d-welcome__subtitle">Open a project folder to get started</p>
          <button className="d-welcome__button" onClick={handleOpenFolder}>
            Open Folder
          </button>
        </div>
      )}

      <CommandPalette open={paletteOpen} onClose={() => setPaletteOpen(false)} onSpawn={handleSpawn} />
      <QuickSwitcher open={searchOpen} onClose={() => setSearchOpen(false)} />
      <SettingsPanel open={settingsOpen} onClose={() => setSettingsOpen(false)} />
    </div>
  );
}
