import React from 'react';
import { useStore } from '../store';
import { SplitContainer } from './SplitContainer';
import { TerminalPane } from './TerminalPane';

interface TerminalAreaProps {
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

export function TerminalArea({ onSpawnInCwd }: TerminalAreaProps) {
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const zenMode = useStore((s) => s.zenMode);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const hasTerminals = activeGroup && activeGroup.terminalIds.length > 0;
  const splitLayout = activeGroup?.splitLayout ?? null;

  if (!hasTerminals || !activeTerminalId) {
    return (
      <div className="d-terminal-area--empty">
        <div style={{ textAlign: 'center' }}>
          <p style={{ color: 'var(--text-dim)' }}>No terminal open</p>
          <p style={{ fontSize: 12, marginTop: 8, color: 'var(--text-dim)' }}>
            Use Quick Launch or press ⌘N
          </p>
        </div>
      </div>
    );
  }

  // Split view: render the split tree
  if (splitLayout) {
    return (
      <div className="d-terminal-area">
        <SplitContainer node={splitLayout} path={[]} />
      </div>
    );
  }

  // Single pane view: render ALL terminals, show/hide with CSS
  // This keeps xterm instances alive so content is preserved when switching
  return (
    <div className="d-terminal-area">
      {activeGroup.terminalIds.map((tid) => (
        <div
          key={tid}
          style={{
            display: tid === activeTerminalId ? 'flex' : 'none',
            flex: '1 1 0%',
            flexDirection: 'column',
            minHeight: 0,
          }}
        >
          <TerminalPane terminalId={tid} onSpawnInCwd={onSpawnInCwd} />
        </div>
      ))}
    </div>
  );
}
