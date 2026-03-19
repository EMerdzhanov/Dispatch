// src/renderer/components/TabBar.tsx
import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

export function TabBar() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const setActiveGroup = useStore((s) => s.setActiveGroup);
  const addGroup = useStore((s) => s.addGroup);

  return (
    <div
      className="flex items-end gap-0.5 px-2 overflow-x-auto"
      style={{ backgroundColor: colors.bg.tertiary, borderBottom: `2px solid ${colors.border.default}` }}
      role="tablist"
    >
      {groups.map((group) => {
        const isActive = group.id === activeGroupId;
        return (
          <button
            key={group.id}
            role="tab"
            aria-selected={isActive}
            className="px-4 py-2 text-xs rounded-t-md shrink-0 transition-colors"
            style={{
              backgroundColor: isActive ? colors.bg.elevated : 'transparent',
              color: isActive ? colors.accent.primary : colors.text.muted,
              borderBottom: isActive ? `2px solid ${colors.accent.primary}` : '2px solid transparent',
            }}
            onClick={() => setActiveGroup(group.id)}
            title={group.cwd || group.label}
          >
            {group.isCustom && '🔧 '}{group.label}
          </button>
        );
      })}
      <button
        className="px-4 py-2 text-xs transition-colors"
        style={{ color: colors.text.dim }}
        onClick={() => addGroup(undefined, 'New Group')}
        title="New project tab"
      >
        +
      </button>
    </div>
  );
}
