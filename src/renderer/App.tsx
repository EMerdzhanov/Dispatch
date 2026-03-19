import React, { useCallback, useEffect } from 'react';
import { TabBar } from './components/TabBar';
import { Sidebar } from './components/Sidebar';
import { TerminalArea } from './components/TerminalArea';
import { useStore } from './store';
import { usePty, useStateApi } from './hooks/usePty';
import { useShortcuts } from './hooks/useShortcuts';
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
        for (const g of data.state.groups) {
          useStore.getState().addGroup(g.cwd, g.label);
        }
      }
    });
  }, []);

  // Listen for PTY exit events
  useEffect(() => {
    const cleanup = pty.onExit((id, code, _signal) => {
      updateTerminalStatus(id, TerminalStatus.EXITED, code);
    });
    return cleanup;
  }, []);

  const handleSpawn = useCallback(async (command: string, env?: Record<string, string>) => {
    const activeGroup = groups.find((g) => g.id === activeGroupId);
    const cwd = activeGroup?.cwd || '/';
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

  const [searchOpen, setSearchOpen] = React.useState(false);
  const [paletteOpen, setPaletteOpen] = React.useState(false);

  const removeTerminal = useStore((s) => s.removeTerminal);
  const addGroup = useStore((s) => s.addGroup);
  const splitTerminal = useStore((s) => s.splitTerminal);
  const toggleZenMode = useStore((s) => s.toggleZenMode);
  const setSettingsOpen = useStore((s) => s.setSettingsOpen);

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
    onSplitHorizontal: () => splitTerminal('horizontal'),
    onSplitVertical: () => splitTerminal('vertical'),
    onToggleZenMode: () => toggleZenMode(),
    onOpenSettings: () => setSettingsOpen(true),
    onMovePaneFocus: (_dir) => { /* pane focus navigation — future enhancement */ },
  });

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
