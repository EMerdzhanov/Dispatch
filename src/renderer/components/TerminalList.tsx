import React from 'react';
import { useStore } from '../store';
import { TerminalEntry } from './TerminalEntry';

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
    <div className="d-termlist">
      <div className="d-termlist__header">
        Terminals ({terminalIds.length})
      </div>

      {/* Filter input with search icon */}
      <div className="d-termlist__filter">
        <span className="d-termlist__filter-icon">⌕</span>
        <input
          type="text"
          placeholder="Filter terminals…"
          value={filterText}
          onChange={(e) => setFilterText(e.target.value)}
          className="d-termlist__filter-input"
        />
      </div>

      {filtered.map((id) => (
        <TerminalEntry key={id} terminalId={id} />
      ))}
    </div>
  );
}
