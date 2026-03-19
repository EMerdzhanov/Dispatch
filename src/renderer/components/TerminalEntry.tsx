import React from 'react';
import { useStore } from '../store';
import { TerminalStatus } from '../../shared/types';
import { colors } from '../theme/colors';

interface TerminalEntryProps {
  terminalId: string;
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
  const isExternal = terminal.isExternal;
  const status = statusConfig[terminal.status];

  return (
    <button
      className="w-full text-left p-2 rounded-md mb-1 transition-colors"
      style={{
        backgroundColor: isActive ? colors.bg.elevated : 'transparent',
        borderLeft: isActive ? `3px solid ${colors.accent.primary}` : '3px solid transparent',
        opacity: isExternal ? 0.6 : 1,
      }}
      onClick={() => setActiveTerminal(terminalId)}
    >
      <div className="text-[11px]" style={{ color: isActive ? colors.text.primary : colors.text.secondary }}>
        {terminal.command.includes('claude') ? 'Claude Code' : 'Shell'}
      </div>
      <div className="text-[9px] mt-0.5 truncate" style={{ color: colors.text.dim }}>
        {terminal.command}
      </div>
      <div className="mt-1">
        <span
          className="text-[8px] px-1.5 py-0.5 rounded"
          style={{ backgroundColor: status.bg, color: status.text }}
        >
          {status.label}
        </span>
      </div>
    </button>
  );
}
