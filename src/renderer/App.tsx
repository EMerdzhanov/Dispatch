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
import { colors } from './theme/colors';

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
  const splitTerminal = useStore((s) => s.splitTerminal);
  const toggleZenMode = useStore((s) => s.toggleZenMode);
  const setSettingsOpen = useStore((s) => s.setSettingsOpen);
  const settingsOpen = useStore((s) => s.settingsOpen);

  useShortcuts({
    onNewTerminal: () => handleSpawn('$SHELL'),
    onNewTab: () => handleOpenFolder(),
    onCloseTerminal: () => {
      const id = useStore.getState().activeTerminalId;
      if (id) {
        pty.kill(id);
        removeTerminal(id);
      }
    },
    onOpenSearch: () => setSearchOpen(true),
    onOpenPalette: () => setPaletteOpen(true),
    onSplitHorizontal: () => splitTerminal('horizontal'),
    onSplitVertical: () => splitTerminal('vertical'),
    onToggleZenMode: () => toggleZenMode(),
    onOpenSettings: () => setSettingsOpen(true),
    onMovePaneFocus: (_dir) => { /* pane focus navigation — future enhancement */ },
  });

  const hasGroups = groups.length > 0;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', backgroundColor: colors.bg.primary, color: colors.text.primary }}>
      {/* Title bar drag region */}
      <div style={{
        height: 32, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '0 16px', flexShrink: 0,
        backgroundColor: colors.bg.tertiary, WebkitAppRegion: 'drag'
      } as React.CSSProperties}>
        <span style={{ fontSize: 11, color: colors.text.muted }}>Dispatch</span>
        <div style={{ display: 'flex', gap: 8, fontSize: 10, color: colors.text.dim, WebkitAppRegion: 'no-drag' } as React.CSSProperties}>
          <span>⌘K Search</span>
          <span>⌘N New</span>
        </div>
      </div>

      {/* Tab bar */}
      <TabBar onSpawnInCwd={handleSpawnInCwd} onOpenFolder={handleOpenFolder} />

      {/* Main content */}
      {hasGroups ? (
        <div style={{ display: 'flex', flex: '1 1 0%', minHeight: 0, overflow: 'hidden' }}>
          <div style={{ width: 224, flexShrink: 0 }}>
            <Sidebar onSpawn={handleSpawn} onSpawnInCwd={handleSpawnInCwd} />
          </div>
          <TerminalArea onSpawnInCwd={handleSpawnInCwd} />
        </div>
      ) : (
        <div style={{
          flex: '1 1 0%', display: 'flex', alignItems: 'center', justifyContent: 'center',
          flexDirection: 'column', gap: 16,
        }}>
          <h1 style={{ fontSize: 24, fontWeight: 600, color: colors.text.primary, margin: 0 }}>
            Welcome to Dispatch
          </h1>
          <p style={{ fontSize: 14, color: colors.text.muted, margin: 0 }}>
            Open a project folder to get started
          </p>
          <button
            onClick={handleOpenFolder}
            style={{
              marginTop: 8,
              padding: '10px 24px',
              borderRadius: 8,
              backgroundColor: colors.accent.primary,
              color: '#fff',
              fontSize: 14,
              fontWeight: 500,
              cursor: 'pointer',
              border: 'none',
            }}
          >
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
