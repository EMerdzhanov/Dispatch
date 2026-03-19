import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

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

    // Find first terminal in group
    const firstTerminal = group.terminalIds[0];
    if (firstTerminal) {
      setActiveTerminal(firstTerminal);
    } else if (group.cwd && onSpawnInCwd) {
      onSpawnInCwd(group.cwd);
    }
  };

  return (
    <div
      className="flex items-end gap-0.5 px-2 overflow-x-auto shrink-0"
      style={{ backgroundColor: colors.bg.tertiary, borderBottom: `2px solid ${colors.border.default}` }}
      role="tablist"
    >
      {groups.map((group) => {
        const isActive = group.id === activeGroupId;
        const count = group.terminalIds.length;
        return (
          <button
            key={group.id}
            role="tab"
            aria-selected={isActive}
            className="px-4 py-2 text-xs rounded-t-md shrink-0 transition-colors flex items-center gap-1.5"
            style={{
              backgroundColor: isActive ? colors.bg.elevated : 'transparent',
              color: isActive ? colors.accent.primary : colors.text.muted,
              borderBottom: isActive ? `2px solid ${colors.accent.primary}` : '2px solid transparent',
            }}
            onClick={() => handleTabClick(group.id)}
            title={group.cwd || group.label}
          >
            {group.isCustom && '🔧 '}{group.label}
            {count > 0 && (
              <span
                className="text-[9px] px-1 rounded-full"
                style={{
                  backgroundColor: isActive ? colors.accent.primary : colors.border.default,
                  color: isActive ? '#fff' : colors.text.dim,
                }}
              >
                {count}
              </span>
            )}
          </button>
        );
      })}
      <button
        className="px-4 py-2 text-xs transition-colors"
        style={{ color: colors.text.dim }}
        onClick={onOpenFolder}
        title="Open project folder (⌘T)"
      >
        +
      </button>
    </div>
  );
}
