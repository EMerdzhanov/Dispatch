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

    const firstTerminal = group.terminalIds[0];
    if (firstTerminal) {
      setActiveTerminal(firstTerminal);
    } else if (group.cwd && onSpawnInCwd) {
      onSpawnInCwd(group.cwd);
    }
  };

  return (
    <div
      style={{
        display: 'flex', alignItems: 'flex-end', gap: 2,
        padding: '0 8px',
        backgroundColor: colors.bg.tertiary,
        borderBottom: `1px solid ${colors.border.default}`,
        overflowX: 'auto', flexShrink: 0,
        height: 38,
      }}
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
            style={{
              display: 'flex', alignItems: 'center', gap: 5,
              padding: '0 14px', height: 30,
              fontSize: 11, flexShrink: 0,
              borderRadius: '4px 4px 0 0',
              border: 'none', cursor: 'pointer',
              transition: 'background-color 0.12s',
              backgroundColor: isActive ? colors.bg.elevated : 'transparent',
              color: isActive ? colors.text.primary : colors.text.muted,
              borderBottom: isActive ? `2px solid ${colors.accent.primary}` : '2px solid transparent',
            }}
            onClick={() => handleTabClick(group.id)}
            title={group.cwd || group.label}
          >
            {/* Folder icon */}
            <span style={{ fontSize: 11, opacity: 0.7 }}>
              {group.isCustom ? '⚙' : '⌂'}
            </span>
            {group.label}
            {count > 0 && (
              <span style={{
                fontSize: 9,
                padding: '1px 5px',
                borderRadius: 8,
                backgroundColor: isActive ? 'rgba(233,69,96,0.25)' : 'rgba(255,255,255,0.08)',
                color: isActive ? colors.accent.primary : colors.text.dim,
              }}>
                {count}
              </span>
            )}
          </button>
        );
      })}
      <button
        style={{
          padding: '0 12px', height: 30,
          fontSize: 16, color: colors.text.dim,
          border: 'none', backgroundColor: 'transparent',
          cursor: 'pointer', flexShrink: 0,
        }}
        onClick={onOpenFolder}
        title="Open project folder (⌘T)"
      >
        +
      </button>
    </div>
  );
}
