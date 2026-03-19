import React, { useRef, useEffect } from 'react';
import { useTerminal } from '../hooks/useTerminal';
import { usePty } from '../hooks/usePty';
import { useStore } from '../store';
import { TerminalStatus } from '../../shared/types';
import { colors } from '../theme/colors';

interface TerminalPaneProps {
  terminalId: string;
}

export function TerminalPane({ terminalId }: TerminalPaneProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const { terminal, fit } = useTerminal(containerRef);
  const pty = usePty();
  const entry = useStore((s) => s.terminals[terminalId]);

  useEffect(() => {
    if (!terminal.current) return;

    const cleanupData = pty.onData((id, data) => {
      if (id === terminalId) {
        terminal.current?.write(data);
      }
    });

    const disposable = terminal.current.onData((data) => {
      pty.write(terminalId, data);
    });

    const resizeDisposable = terminal.current.onResize(({ cols, rows }) => {
      pty.resize(terminalId, cols, rows);
    });

    return () => {
      cleanupData();
      disposable.dispose();
      resizeDisposable.dispose();
    };
  }, [terminal.current, terminalId, pty]);

  if (!entry) return null;

  const isExited = entry.status === TerminalStatus.EXITED;

  return (
    <div className="flex flex-col flex-1 overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-3 py-1.5 border-b"
        style={{ backgroundColor: colors.bg.tertiary, borderColor: colors.border.default }}>
        <div className="flex items-center gap-2">
          <span style={{ color: colors.accent.primary }}>●</span>
          <span className="text-xs" style={{ color: colors.text.secondary }}>
            {entry.command} — {entry.cwd}
          </span>
        </div>
        <div className="flex gap-3 text-xs" style={{ color: colors.text.dim }}>
          <span>Split ⌘D</span>
          <span>Close ⌘W</span>
        </div>
      </div>

      {/* Terminal */}
      <div ref={containerRef} className="flex-1 relative">
        {isExited && (
          <div className="absolute inset-0 flex items-center justify-center bg-black/60 z-10">
            <div className="text-center">
              <p style={{ color: colors.text.muted }}>
                Process exited with code {entry.exitCode ?? 'unknown'}
              </p>
              <p className="mt-2 text-xs" style={{ color: colors.text.dim }}>
                Press any key to close or click Restart
              </p>
              <button
                className="mt-3 px-4 py-1.5 rounded text-xs"
                style={{ backgroundColor: colors.accent.blue, color: colors.accent.blueLight }}
              >
                Restart
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
