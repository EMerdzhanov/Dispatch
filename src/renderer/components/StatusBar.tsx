import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

export function StatusBar() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const terminals = useStore((s) => s.terminals);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const terminalIds = activeGroup?.terminalIds ?? [];
  const totalCount = terminalIds.length;
  const externalCount = terminalIds.filter((id) => terminals[id]?.isExternal).length;

  return (
    <div
      className="flex items-center justify-between px-2.5 py-1.5 text-[9px] border-t"
      style={{ color: colors.text.dim, borderColor: colors.border.default }}
    >
      <span>{totalCount} terminals</span>
      <span>{externalCount} external</span>
    </div>
  );
}
