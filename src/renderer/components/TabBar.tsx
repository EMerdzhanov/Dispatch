import React from 'react';
import { useStore } from '../store';

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

  return (
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
            title={group.cwd || group.label}
          >
            {/* Folder icon */}
            <span className="d-tab__icon">
              {group.isCustom ? '⚙' : '⌂'}
            </span>
            {group.label}
            {count > 0 && (
              <span className="d-tab__badge">{count}</span>
            )}
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
    </div>
  );
}
