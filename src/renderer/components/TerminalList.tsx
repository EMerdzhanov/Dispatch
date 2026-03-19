import React from 'react';
import { useStore } from '../store';
import { TerminalEntry } from './TerminalEntry';
import { colors } from '../theme/colors';

interface TerminalListProps {
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

export function TerminalList({ onSpawnInCwd }: TerminalListProps) {
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
    <div style={{ flex: 1, overflowY: 'auto', padding: '8px 8px 4px' }}>
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        marginBottom: 6, padding: '0 2px',
      }}>
        <span style={{ fontSize: 9, textTransform: 'uppercase', letterSpacing: '0.12em', color: colors.text.dim }}>
          Terminals ({terminalIds.length})
        </span>
      </div>

      {/* Filter input with search icon */}
      <div style={{ position: 'relative', marginBottom: 8 }}>
        <span style={{
          position: 'absolute', left: 7, top: '50%', transform: 'translateY(-50%)',
          fontSize: 10, color: colors.text.dim, pointerEvents: 'none', userSelect: 'none',
        }}>
          ⌕
        </span>
        <input
          type="text"
          placeholder="Filter terminals…"
          value={filterText}
          onChange={(e) => setFilterText(e.target.value)}
          style={{
            width: '100%', boxSizing: 'border-box',
            padding: '4px 8px 4px 22px',
            borderRadius: 5,
            fontSize: 11,
            border: `1px solid ${colors.border.subtle}`,
            backgroundColor: colors.bg.primary,
            color: colors.text.secondary,
            outline: 'none',
          }}
        />
      </div>

      {filtered.map((id) => (
        <TerminalEntry key={id} terminalId={id} />
      ))}
    </div>
  );
}
