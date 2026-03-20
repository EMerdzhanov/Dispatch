import React, { useState } from 'react';
import { useStore } from '../store';
import { usePty } from '../hooks/usePty';

interface TabBarProps {
  onSpawnInCwd?: (cwd: string, command?: string) => void;
  onOpenFolder?: () => void;
}

export function TabBar({ onSpawnInCwd, onOpenFolder }: TabBarProps) {
  const groups = useStore((s) => s.groups);
  const terminals = useStore((s) => s.terminals);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const setActiveGroup = useStore((s) => s.setActiveGroup);
  const setActiveTerminal = useStore((s) => s.setActiveTerminal);
  const removeGroup = useStore((s) => s.removeGroup);
  const removeTerminal = useStore((s) => s.removeTerminal);
  const pty = usePty();
  const [contextMenu, setContextMenu] = useState<{ groupId: string; x: number; y: number } | null>(null);

  const handleTabClick = (groupId: string) => {
    setActiveGroup(groupId);
    const group = groups.find((g) => g.id === groupId);
    if (!group) return;

    const firstTerminal = group.terminalIds[0];
    if (firstTerminal) {
      setActiveTerminal(firstTerminal);
    } else if (group.cwd && onSpawnInCwd) {
      onSpawnInCwd(group.cwd);
    }
  };

  const handleCloseTab = (groupId: string) => {
    const group = groups.find((g) => g.id === groupId);
    if (group) {
      for (const tid of group.terminalIds) {
        pty.kill(tid);
        removeTerminal(tid);
      }
    }
    removeGroup(groupId);
    setContextMenu(null);
  };

  return (
    <>
      <div className="d-tabbar" role="tablist">
        {groups.map((group) => {
          const isActive = group.id === activeGroupId;
          const count = group.terminalIds.length;
          return (
            <button
              key={group.id}
              role="tab"
              aria-selected={isActive}
              className={`d-tab${isActive ? ' d-tab--active' : ''}`}
              onClick={() => handleTabClick(group.id)}
              onContextMenu={(e) => {
                e.preventDefault();
                setContextMenu({ groupId: group.id, x: e.clientX, y: e.clientY });
              }}
              title={group.cwd || group.label}
            >
              <span className="d-tab__icon">{group.isCustom ? '⚙' : '⌂'}</span>
              {group.label}
              {count > 0 && <span className="d-tab__badge">{count}</span>}
            </button>
          );
        })}
        <button
          className="d-tab d-tab--add"
          onClick={onOpenFolder}
          title="Open project folder (⌘T)"
        >
          +
        </button>

        {/* Spacer pushes gear to far right */}
        <div style={{ flex: 1 }} />

        <button
          className="d-tab d-tab--add"
          onClick={() => useStore.getState().setShortcutsOpen(true)}
          title="Keyboard Shortcuts (⌘?)"
          style={{ fontSize: 16 }}
        >
          ?
        </button>
        <button
          className="d-tab d-tab--add"
          onClick={() => useStore.getState().setSettingsOpen(true)}
          title="Settings (⌘,)"
          style={{ fontSize: 16 }}
        >
          ⚙
        </button>
      </div>

      {/* Tab context menu — fixed position using mouse coordinates */}
      {contextMenu && (
        <>
          <div className="d-context-overlay" onClick={() => setContextMenu(null)} />
          <div className="d-context-menu" style={{
            position: 'fixed',
            top: contextMenu.y,
            left: contextMenu.x,
            right: 'auto',
          }}>
            <button
              className="d-context-menu__item d-context-menu__item--danger"
              onClick={() => handleCloseTab(contextMenu.groupId)}
            >
              Close Tab
            </button>
          </div>
        </>
      )}
    </>
  );
}
