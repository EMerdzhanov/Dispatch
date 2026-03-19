import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

export function StatusBar() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const totalCount = activeGroup?.terminalIds.length ?? 0;

  return (
    <div
      className="flex items-center justify-between px-2.5 py-1.5 text-[9px] border-t"
      style={{ color: colors.text.dim, borderColor: colors.border.default }}
    >
      <span>{totalCount} terminal{totalCount !== 1 ? 's' : ''}</span>
    </div>
  );
}
