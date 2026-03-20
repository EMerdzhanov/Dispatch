import React, { useState, useRef, useEffect } from 'react';
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
  const renameTerminal = useStore((s) => s.renameTerminal);
  const pty = usePty();
  const [showMenu, setShowMenu] = useState(false);
  const [editing, setEditing] = useState(false);
  const [editName, setEditName] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (editing) {
      setTimeout(() => inputRef.current?.select(), 50);
    }
  }, [editing]);

  if (!terminal) return null;

  const isActive = terminalId === activeTerminalId;
  const isExited = terminal.status === TerminalStatus.EXITED;

  const isClaude = terminal.command === 'claude' || terminal.command.startsWith('claude ');
  const defaultName = isClaude ? 'Claude Code' : 'Shell';
  const displayName = terminal.label || defaultName;

  const activityStatus = useStore((s) => s.terminalStatuses[terminalId]) || 'idle';

  const activityColors: Record<string, string> = {
    idle: 'var(--text-dim)',
    running: 'var(--accent-blue-light)',
    success: 'var(--accent-green)',
    error: 'var(--accent-primary)',
    waiting: 'var(--accent-yellow)',
  };

  const dotColor = activityColors[activityStatus] || 'var(--text-dim)';
  const isRunningAnim = activityStatus === 'running';

  const handleClose = () => {
    pty.kill(terminalId);
    removeTerminal(terminalId);
    setShowMenu(false);
  };

  const handleContextMenu = (e: React.MouseEvent) => {
    e.preventDefault();
    setShowMenu(true);
  };

  const startRename = () => {
    setEditName(terminal.label || defaultName);
    setEditing(true);
    setShowMenu(false);
  };

  const commitRename = () => {
    const trimmed = editName.trim();
    if (trimmed && trimmed !== defaultName) {
      renameTerminal(terminalId, trimmed);
    } else {
      // Clear custom label to revert to default
      renameTerminal(terminalId, '');
    }
    setEditing(false);
  };

  return (
    <div style={{ position: 'relative' }}>
      <button
        className={`d-entry${isActive ? ' d-entry--active' : ''}${isExited ? ' d-entry--exited' : ''}`}
        onClick={() => setActiveTerminal(terminalId)}
        onDoubleClick={startRename}
        onContextMenu={handleContextMenu}
        title={`${displayName} — ${terminal.command}`}
      >
        <div className="d-entry__header">
          <span className={`d-entry__dot${isRunningAnim ? ' d-entry__dot--running' : ''}`} style={{ backgroundColor: dotColor }} />
          {editing ? (
            <input
              ref={inputRef}
              className="d-settings__input"
              style={{ fontSize: 11, padding: '1px 4px', width: '100%' }}
              value={editName}
              onChange={(e) => setEditName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') commitRename();
                if (e.key === 'Escape') setEditing(false);
                e.stopPropagation();
              }}
              onBlur={commitRename}
              onClick={(e) => e.stopPropagation()}
            />
          ) : (
            <span className="d-entry__name">{displayName}</span>
          )}
        </div>
        <div className="d-entry__command">{terminal.command}</div>
      </button>

      {showMenu && (
        <>
          <div className="d-context-overlay" onClick={() => setShowMenu(false)} />
          <div className="d-context-menu">
            <button className="d-context-menu__item" onClick={startRename}>
              Rename
            </button>
            <button className="d-context-menu__item d-context-menu__item--danger" onClick={handleClose}>
              Close Terminal
            </button>
          </div>
        </>
      )}
    </div>
  );
}
