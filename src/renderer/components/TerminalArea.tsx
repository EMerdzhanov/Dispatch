import React from 'react';
import { useStore } from '../store';
import { SplitContainer } from './SplitContainer';
import { TerminalPane } from './TerminalPane';
import { SubTabBar } from './SubTabBar';
import { BrowserPanel } from './BrowserPanel';

interface TerminalAreaProps {
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

export function TerminalArea({ onSpawnInCwd }: TerminalAreaProps) {
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const zenMode = useStore((s) => s.zenMode);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const activeBrowserTabId = useStore((s) => s.activeBrowserTabId);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const hasTerminals = activeGroup && activeGroup.terminalIds.length > 0;
  const splitLayout = activeGroup?.splitLayout ?? null;
  const showBrowser = activeBrowserTabId !== null;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: '1 1 0%', minHeight: 0 }}>
      <SubTabBar />

      {/* Browser view — always mounted when tabs exist, shown/hidden with CSS */}
      {activeBrowserTabId && (
        <div style={{ display: showBrowser ? 'flex' : 'none', flex: '1 1 0%', minHeight: 0 }}>
          <BrowserPanel tabId={activeBrowserTabId} />
        </div>
      )}

      {/* Terminal view — always mounted, shown/hidden with CSS */}
      <div style={{
        display: showBrowser ? 'none' : 'flex',
        flexDirection: 'column',
        flex: '1 1 0%',
        minHeight: 0,
      }}>
        {(!hasTerminals || !activeTerminalId) ? (
          <div className="d-terminal-area--empty">
            <div style={{ textAlign: 'center' }}>
              <p style={{ color: 'var(--text-dim)' }}>No terminal open</p>
              <p style={{ fontSize: 12, marginTop: 8, color: 'var(--text-dim)' }}>
                Use Quick Launch or press ⌘N
              </p>
            </div>
          </div>
        ) : splitLayout ? (
          <div className="d-terminal-area">
            <SplitContainer node={splitLayout} path={[]} />
          </div>
        ) : (
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
        )}
      </div>
    </div>
  );
}
