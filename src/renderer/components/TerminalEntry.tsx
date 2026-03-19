import React from 'react';
import { useStore } from '../store';
import { TerminalStatus } from '../../shared/types';
import { colors } from '../theme/colors';

interface TerminalEntryProps {
  terminalId: string;
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

const statusConfig = {
  [TerminalStatus.ACTIVE]: { label: 'ACTIVE', ...colors.status.active },
  [TerminalStatus.RUNNING]: { label: 'RUNNING', ...colors.status.running },
  [TerminalStatus.EXITED]: { label: 'EXITED', ...colors.status.exited },
  [TerminalStatus.EXTERNAL]: { label: 'EXTERNAL', ...colors.status.external },
  [TerminalStatus.ATTACHING]: { label: 'ATTACHING', ...colors.status.attaching },
};

export function TerminalEntry({ terminalId }: TerminalEntryProps) {
  const terminal = useStore((s) => s.terminals[terminalId]);
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const setActiveTerminal = useStore((s) => s.setActiveTerminal);

  if (!terminal) return null;

  const isActive = terminalId === activeTerminalId;
  const status = statusConfig[terminal.status];

  const isClaude = terminal.command === 'claude' || terminal.command.startsWith('claude ');
  const typeName = isClaude ? 'Claude Code' : 'Shell';
  const typeColor = isClaude ? colors.accent.blueLight : colors.text.muted;

  return (
    <button
      className="w-full text-left p-2 rounded-md mb-1 transition-colors"
      style={{
        backgroundColor: isActive ? colors.bg.elevated : 'transparent',
        borderLeft: isActive ? `3px solid ${colors.accent.primary}` : '3px solid transparent',
      }}
      onClick={() => setActiveTerminal(terminalId)}
      title={terminal.command}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ fontSize: 11, fontWeight: 500, color: typeColor }}>
          {typeName}
        </span>
      </div>
      <div style={{ fontSize: 9, marginTop: 2, color: colors.text.dim, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        {terminal.command}
      </div>
      <div style={{ marginTop: 4, display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{
          fontSize: 8, padding: '2px 6px', borderRadius: 3,
          backgroundColor: status.bg, color: status.text
        }}>
          {status.label}
        </span>
        {terminal.pid && (
          <span style={{ fontSize: 8, color: colors.text.dim }}>
            PID {terminal.pid}
          </span>
        )}
      </div>
    </button>
  );
}
