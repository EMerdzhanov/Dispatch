import React from 'react';
import { useStore } from '../store';
import { TerminalEntry } from './TerminalEntry';
import { colors } from '../theme/colors';

export function TerminalList() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const terminals = useStore((s) => s.terminals);
  const filterText = useStore((s) => s.filterText);
  const setFilterText = useStore((s) => s.setFilterText);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const terminalIds = activeGroup?.terminalIds ?? [];
  const filtered = filterText
    ? terminalIds.filter((id) => {
        const t = terminals[id];
        return t && t.command.toLowerCase().includes(filterText.toLowerCase());
      })
    : terminalIds;

  return (
    <div className="flex-1 overflow-y-auto px-1.5">
      <div className="px-1.5 mb-1.5 flex items-center justify-between">
        <span className="text-[9px] uppercase tracking-widest" style={{ color: colors.text.dim }}>
          Terminals ({terminalIds.length})
        </span>
      </div>
      <input
        type="text"
        placeholder="Filter terminals..."
        value={filterText}
        onChange={(e) => setFilterText(e.target.value)}
        className="w-full px-2 py-1 mb-2 rounded text-xs border outline-none"
        style={{
          backgroundColor: colors.bg.tertiary,
          borderColor: colors.border.default,
          color: colors.text.primary,
        }}
      />
      {filtered.map((id) => (
        <TerminalEntry key={id} terminalId={id} />
      ))}
    </div>
  );
}
