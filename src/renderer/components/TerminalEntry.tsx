import React, { useState } from 'react';
import { useStore } from '../store';
import { TerminalStatus } from '../../shared/types';
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
  const dotColor = isClaude ? '#53a8ff' : '#888888';

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
        className={`d-entry${isActive ? ' d-entry--active' : ''}${isExited ? ' d-entry--exited' : ''}`}
        onClick={() => setActiveTerminal(terminalId)}
        onContextMenu={handleContextMenu}
        title={terminal.command}
      >
        <div className="d-entry__header">
          <span className="d-entry__dot" style={{ backgroundColor: dotColor }} />
          <span className="d-entry__name">{typeName}</span>
        </div>
        <div className="d-entry__command">{terminal.command}</div>
      </button>

      {/* Right-click context menu */}
      {showMenu && (
        <>
          {/* Click-away overlay */}
          <div
            className="d-context-overlay"
            onClick={() => setShowMenu(false)}
          />
          <div className="d-context-menu">
            <button
              className="d-context-menu__item"
              onClick={handleClose}
            >
              Close Terminal
            </button>
            <button
              className="d-context-menu__item d-context-menu__item--danger"
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
