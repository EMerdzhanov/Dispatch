import React, { useCallback, useEffect } from 'react';
import { TabBar } from './components/TabBar';
import { Sidebar } from './components/Sidebar';
import { TerminalArea } from './components/TerminalArea';
import { CommandPalette } from './components/CommandPalette';
import { QuickSwitcher } from './components/QuickSwitcher';
import { SettingsPanel } from './components/SettingsPanel';
import { ShortcutsPanel } from './components/ShortcutsPanel';
import { SaveTemplateDialog } from './components/SaveTemplateDialog';
import { ResumeModal } from './components/ResumeModal';
import { useStore } from './store';
import { usePty, useStateApi, useDialogApi } from './hooks/usePty';
import { useShortcuts } from './hooks/useShortcuts';
import { TerminalStatus } from '../shared/types';
import type { SplitNode, SplitDirection, Template, TemplateNode } from '../shared/types';

// Build an equal split layout from a list of terminal IDs
function buildEqualSplit(terminalIds: string[], direction: SplitDirection): SplitNode {
  if (terminalIds.length === 1) {
    return { type: 'leaf', terminalId: terminalIds[0] };
  }
  if (terminalIds.length === 2) {
    return {
      type: 'branch',
      direction,
      ratio: 0.5,
      children: [
        { type: 'leaf', terminalId: terminalIds[0] },
        { type: 'leaf', terminalId: terminalIds[1] },
      ] as [SplitNode, SplitNode],
    };
  }
  // 3+ terminals: split in half, recurse
  const mid = Math.ceil(terminalIds.length / 2);
  return {
    type: 'branch',
    direction,
    ratio: mid / terminalIds.length,
    children: [
      buildEqualSplit(terminalIds.slice(0, mid), direction),
      buildEqualSplit(terminalIds.slice(mid), direction),
    ] as [SplitNode, SplitNode],
  };
}

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

function splitNodeToTemplate(node: SplitNode, terminals: Record<string, any>): TemplateNode {
  if (node.type === 'leaf') {
    const term = terminals[node.terminalId];
    return { type: 'leaf', command: term?.command || '$SHELL' };
  }
  return {
    type: 'branch',
    direction: node.direction,
    ratio: node.ratio,
    children: [
      splitNodeToTemplate(node.children[0], terminals),
      splitNodeToTemplate(node.children[1], terminals),
    ] as [TemplateNode, TemplateNode],
  };
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
  const [saveTemplateOpen, setSaveTemplateOpen] = React.useState(false);
  const [showResume, setShowResume] = React.useState(false);
  const templates = useStore((s) => s.templates);

  useEffect(() => {
    (window as any).dispatch?.tmux?.isAvailable().then((available: boolean) => {
      useStore.getState().setTmuxAvailable(available);
    });
  }, []);

  useEffect(() => {
    (window as any).dispatch?.templates?.load().then((t: Template[]) => {
      if (t) useStore.getState().setTemplates(t);
    });
  }, []);

  useEffect(() => {
    (window as any).dispatch?.resume?.scan().then((sessions: any[]) => {
      if (sessions && sessions.length > 0) {
        const mapped = sessions.map((s: any) => ({
          sessionName: s.name,
          cwd: s.cwd,
          folderName: s.cwd ? s.cwd.split('/').pop() || s.name : s.name,
          selected: true,
        }));
        useStore.getState().setResumeSessions(mapped);
        setShowResume(true);
      }
    });
  }, []);

  const monitorRef = React.useRef(false);
  useEffect(() => {
    if (monitorRef.current) return;
    monitorRef.current = true;
    (window as any).dispatch?.monitor?.onStatus((id: string, status: string) => {
      useStore.getState().setTerminalStatus(id, status as any);
    });
  }, []);

  const browserDetectRef = React.useRef(false);
  useEffect(() => {
    if (browserDetectRef.current) return;
    browserDetectRef.current = true;
    (window as any).dispatch?.browser?.onDetected((terminalId: string, url: string) => {
      const state = useStore.getState();
      const group = state.groups.find((g) => g.terminalIds.includes(terminalId));
      if (!group) return;

      // Check if a tab for this port already exists
      let port = '';
      try { port = new URL(url).port; } catch { return; }
      const existingTab = (group.browserTabIds || [])
        .map((id) => state.browserTabs[id])
        .find((t) => { try { return t && new URL(t.url).port === port; } catch { return false; } });

      if (existingTab) return;

      let host = url;
      try { host = new URL(url).host; } catch {}
      const tab = { id: crypto.randomUUID(), url, title: host };
      state.addBrowserTab(group.id, tab);
    });
  }, []);

  // Load project data when active group changes
  useEffect(() => {
    const group = groups.find((g) => g.id === activeGroupId);
    if (!group?.cwd) return;
    const cwd = group.cwd;

    (window as any).dispatch?.project?.loadTasks(cwd).then((t: any) => {
      useStore.getState().setProjectTasks(t || []);
    });
    (window as any).dispatch?.project?.loadNotes(cwd).then((n: any) => {
      useStore.getState().setProjectNotes(n || []);
    });
    (window as any).dispatch?.project?.loadVault(cwd).then((v: any) => {
      useStore.getState().setProjectVault(v || []);
    });
  }, [activeGroupId]);

  const handleSaveTemplate = async (name: string) => {
    const state = useStore.getState();
    const group = state.groups.find((g) => g.id === state.activeGroupId);
    if (!group) return;

    let templateLayout: TemplateNode | null = null;
    if (group.splitLayout) {
      templateLayout = splitNodeToTemplate(group.splitLayout, state.terminals);
    } else if (group.terminalIds.length === 1) {
      const term = state.terminals[group.terminalIds[0]];
      templateLayout = { type: 'leaf', command: term?.command || '$SHELL' };
    }

    const template: Template = { name, cwd: group.cwd || '/', splitLayout: templateLayout };
    const updated = [...state.templates, template];
    state.setTemplates(updated);
    await (window as any).dispatch.templates.save(updated);
    setSaveTemplateOpen(false);
  };

  const handleRestoreTemplate = async (template: Template) => {
    const groupId = findOrCreateGroup(template.cwd);
    useStore.getState().setActiveGroup(groupId);

    if (!template.splitLayout) {
      const id = await pty.spawn({ cwd: template.cwd, command: '$SHELL' });
      addTerminal(groupId, { id, command: '$SHELL', cwd: template.cwd, status: TerminalStatus.RUNNING });
      setActiveTerminal(id);
      return;
    }

    async function spawnFromTemplate(tNode: TemplateNode, cwd: string): Promise<SplitNode> {
      if (tNode.type === 'leaf') {
        const id = await pty.spawn({ cwd, command: tNode.command });
        addTerminal(groupId, { id, command: tNode.command, cwd, status: TerminalStatus.RUNNING });
        return { type: 'leaf', terminalId: id };
      }
      const left = await spawnFromTemplate(tNode.children[0], cwd);
      const right = await spawnFromTemplate(tNode.children[1], cwd);
      return {
        type: 'branch',
        direction: tNode.direction,
        ratio: tNode.ratio,
        children: [left, right] as [SplitNode, SplitNode],
      };
    }

    const liveLayout = await spawnFromTemplate(template.splitLayout, template.cwd);
    useStore.getState().setGroupSplitLayout(groupId, liveLayout);

    function firstLeaf(n: SplitNode): string {
      return n.type === 'leaf' ? n.terminalId : firstLeaf(n.children[0]);
    }
    setActiveTerminal(firstLeaf(liveLayout));
  };

  const handleRestore = async () => {
    const sessions = useStore.getState().resumeSessions?.filter((s) => s.selected) || [];
    for (const session of sessions) {
      if (!session.cwd) continue;
      const groupId = findOrCreateGroup(session.cwd);
      const id = await (window as any).dispatch.resume.restore(session.sessionName);
      addTerminal(groupId, { id, command: 'tmux (restored)', cwd: session.cwd, status: TerminalStatus.RUNNING });
    }
    if (sessions.length > 0) {
      const firstGroup = useStore.getState().groups[0];
      if (firstGroup) {
        useStore.getState().setActiveGroup(firstGroup.id);
        if (firstGroup.terminalIds[0]) setActiveTerminal(firstGroup.terminalIds[0]);
      }
    }
    setShowResume(false);
    useStore.getState().setResumeSessions(null);
  };

  const handleFresh = async () => {
    const sessions = useStore.getState().resumeSessions || [];
    await (window as any).dispatch.resume.cleanup(sessions.map((s) => s.sessionName));
    setShowResume(false);
    useStore.getState().setResumeSessions(null);
  };

  const removeTerminal = useStore((s) => s.removeTerminal);
  const addGroup = useStore((s) => s.addGroup);
  const toggleZenMode = useStore((s) => s.toggleZenMode);
  const setSettingsOpen = useStore((s) => s.setSettingsOpen);
  const settingsOpen = useStore((s) => s.settingsOpen);
  const setShortcutsOpen = useStore((s) => s.setShortcutsOpen);
  const shortcutsOpen = useStore((s) => s.shortcutsOpen);

  useShortcuts({
    onNewTerminal: () => handleSpawn('$SHELL'),
    onNewTab: () => handleOpenFolder(),
    onCloseTerminal: () => {
      // Cmd+W: if in split view, exit split view (don't kill terminal)
      // If NOT in split view, do nothing (use right-click to kill terminals)
      const state = useStore.getState();
      const group = state.groups.find((g) => g.id === state.activeGroupId);
      if (!group) return;

      if (group.splitLayout) {
        // Exit split view — go back to single pane showing active terminal
        state.setGroupSplitLayout(group.id, null);
        return;
      }
      // No split view — do nothing (terminals are closed via right-click context menu)
    },
    onOpenSearch: () => setSearchOpen(true),
    onOpenPalette: () => setPaletteOpen(true),
    onSplitHorizontal: () => {
      // Cmd+D: arrange existing terminals into horizontal split (no new terminal spawned)
      const state = useStore.getState();
      const group = state.groups.find((g) => g.id === state.activeGroupId);
      if (!group || group.terminalIds.length < 2) return; // need at least 2 terminals to split

      // Build a split tree from all terminals in the group
      const layout = buildEqualSplit(group.terminalIds, 'horizontal');
      state.setGroupSplitLayout(group.id, layout);
    },
    onSplitVertical: () => {
      const state = useStore.getState();
      const group = state.groups.find((g) => g.id === state.activeGroupId);
      if (!group || group.terminalIds.length < 2) return;

      const layout = buildEqualSplit(group.terminalIds, 'vertical');
      state.setGroupSplitLayout(group.id, layout);
    },
    onToggleZenMode: () => toggleZenMode(),
    onOpenSettings: () => setSettingsOpen(true),
    onOpenShortcuts: () => setShortcutsOpen(true),
    onMovePaneFocus: (_dir) => { /* pane focus navigation — future enhancement */ },
    onSaveTemplate: () => setSaveTemplateOpen(true),
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
          {templates.length > 0 && (
            <div style={{ marginTop: 24, width: 400 }}>
              <div className="d-quicklaunch__label">Saved Templates</div>
              {templates.map((t, i) => (
                <button key={i} className="d-entry" style={{ width: '100%', marginBottom: 4 }}
                  onClick={() => handleRestoreTemplate(t)}>
                  <div className="d-entry__header">
                    <span className="d-entry__dot" style={{ backgroundColor: 'var(--accent-blue-light)' }} />
                    <span className="d-entry__name">{t.name}</span>
                  </div>
                  <div className="d-entry__command">{t.cwd}</div>
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      {showResume && <ResumeModal onRestore={handleRestore} onFresh={handleFresh} />}
      <CommandPalette open={paletteOpen} onClose={() => setPaletteOpen(false)} onSpawn={handleSpawn} />
      <QuickSwitcher open={searchOpen} onClose={() => setSearchOpen(false)} />
      <SettingsPanel open={settingsOpen} onClose={() => setSettingsOpen(false)} />
      <ShortcutsPanel open={shortcutsOpen} onClose={() => setShortcutsOpen(false)} />
      <SaveTemplateDialog
        open={saveTemplateOpen}
        defaultName={groups.find((g) => g.id === activeGroupId)?.label || 'My Workspace'}
        onSave={handleSaveTemplate}
        onClose={() => setSaveTemplateOpen(false)}
      />
    </div>
  );
}
