import React, { useState } from 'react';
import { useStore } from '../store';

interface BrowserConsoleProps {
  tabId: string;
}

export function BrowserConsole({ tabId }: BrowserConsoleProps) {
  const messages = useStore((s) => s.consoleMessages[tabId]) || [];
  const clearMessages = useStore((s) => s.clearConsoleMessages);
  const pipeToTerminal = useStore((s) => s.pipeToTerminal);
  const togglePipe = useStore((s) => s.togglePipeToTerminal);
  const [expanded, setExpanded] = useState(false);

  const errorCount = messages.filter((m) => m.level === 'error').length;
  const totalCount = messages.length;
  const levelIcons = { info: 'ℹ', warn: '⚠', error: '✕' };

  return (
    <div className="d-console">
      <button className="d-console__toggle" onClick={() => setExpanded(!expanded)}>
        <span>
          Console {totalCount > 0 && <span className="d-console__badge">{totalCount}</span>}
          {errorCount > 0 && <span style={{ color: 'var(--accent-primary)', marginLeft: 4, fontSize: 9 }}>{errorCount} errors</span>}
        </span>
        <span>{expanded ? '▼' : '▲'}</span>
      </button>
      {expanded && (
        <>
          <div className="d-console__list">
            {messages.length === 0 && (
              <div className="d-console__item d-console__item--info">
                <span className="d-console__msg">No console messages yet</span>
              </div>
            )}
            {messages.map((msg, i) => (
              <div key={i} className={`d-console__item d-console__item--${msg.level}`}>
                <span className="d-console__time">{new Date(msg.timestamp).toLocaleTimeString()}</span>
                <span className="d-console__level">{levelIcons[msg.level]}</span>
                <span className="d-console__msg">{msg.message}</span>
              </div>
            ))}
          </div>
          <div className="d-console__actions">
            <button className="d-console__action" onClick={() => clearMessages(tabId)}>Clear</button>
            <button
              className={`d-console__action${pipeToTerminal ? ' d-console__action--active' : ''}`}
              onClick={togglePipe}
            >
              {pipeToTerminal ? '✓ Piping to Terminal' : 'Pipe to Terminal'}
            </button>
          </div>
        </>
      )}
    </div>
  );
}
