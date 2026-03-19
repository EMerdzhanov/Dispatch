import React, { useState } from 'react';
import { useStore } from '../store';
import { TerminalStatus } from '../../shared/types';
import { colors } from '../theme/colors';
import { usePty } from '../hooks/usePty';

interface TerminalEntryProps {
  terminalId: string;
}

export function TerminalEntry({ terminalId }: TerminalEntryProps) {
  const terminal = useStore((s) => s.terminals[terminalId]);
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const setActiveTerminal = useStore((s) => s.setActiveTerminal);
  const removeTerminal = useStore((s) => s.removeTerminal);
  const pty = usePty();
  const [showMenu, setShowMenu] = useState(false);

  if (!terminal) return null;

  const isActive = terminalId === activeTerminalId;
  const isExited = terminal.status === TerminalStatus.EXITED;

  const isClaude = terminal.command === 'claude' || terminal.command.startsWith('claude ');
  const typeName = isClaude ? 'Claude Code' : 'Shell';
  const dotColor = isClaude ? colors.accent.blueLight : '#888888';

  const handleClose = () => {
    pty.kill(terminalId);
    removeTerminal(terminalId);
    setShowMenu(false);
  };

  const handleContextMenu = (e: React.MouseEvent) => {
    e.preventDefault();
    setShowMenu(true);
  };

  return (
    <div style={{ position: 'relative' }}>
      <button
        style={{
          width: '100%', textAlign: 'left',
          padding: '5px 8px 5px 10px',
          borderRadius: 4,
          marginBottom: 2,
          border: 'none', cursor: 'pointer',
          backgroundColor: isActive ? colors.bg.elevated : 'transparent',
          borderLeft: isActive
            ? `2px solid ${colors.accent.primary}`
            : '2px solid transparent',
          opacity: isExited ? 0.45 : 1,
        }}
        onClick={() => setActiveTerminal(terminalId)}
        onContextMenu={handleContextMenu}
        title={terminal.command}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 7, color: dotColor, lineHeight: 1, flexShrink: 0 }}>●</span>
          <span style={{
            fontSize: 11,
            fontWeight: isActive ? 600 : 400,
            color: isActive ? colors.text.primary : colors.text.secondary,
            textDecoration: isExited ? 'line-through' : 'none',
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          }}>
            {typeName}
          </span>
        </div>
        <div style={{
          fontSize: 9, marginTop: 2,
          color: colors.text.dim,
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const,
          paddingLeft: 13,
        }}>
          {terminal.command}
        </div>
      </button>

      {/* Right-click context menu */}
      {showMenu && (
        <>
          {/* Click-away overlay */}
          <div
            style={{ position: 'fixed', inset: 0, zIndex: 99 }}
            onClick={() => setShowMenu(false)}
          />
          <div style={{
            position: 'absolute', right: 4, top: 4, zIndex: 100,
            backgroundColor: colors.bg.tertiary, border: `1px solid ${colors.border.default}`,
            borderRadius: 6, padding: 4, minWidth: 140,
            boxShadow: '0 4px 12px rgba(0,0,0,0.4)',
          }}>
            <button
              style={{
                width: '100%', textAlign: 'left', padding: '6px 10px', borderRadius: 4,
                fontSize: 12, color: colors.text.secondary, border: 'none',
                backgroundColor: 'transparent', cursor: 'pointer',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.bg.elevated)}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
              onClick={handleClose}
            >
              Close Terminal
            </button>
            <button
              style={{
                width: '100%', textAlign: 'left', padding: '6px 10px', borderRadius: 4,
                fontSize: 12, color: colors.accent.primary, border: 'none',
                backgroundColor: 'transparent', cursor: 'pointer',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.bg.elevated)}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
              onClick={() => {
                pty.kill(terminalId);
                removeTerminal(terminalId);
                const state = useStore.getState();
                const group = state.groups.find((g) => g.terminalIds.includes(terminalId));
                if (group) {
                  for (const tid of group.terminalIds) {
                    if (tid !== terminalId) {
                      pty.kill(tid);
                      state.removeTerminal(tid);
                    }
                  }
                }
                setShowMenu(false);
              }}
            >
              Close All in Tab
            </button>
          </div>
        </>
      )}
    </div>
  );
}
