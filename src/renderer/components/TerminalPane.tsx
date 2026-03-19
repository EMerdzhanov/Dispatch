import React, { useRef, useEffect, useState } from 'react';
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import { SearchAddon } from 'xterm-addon-search';
import { Unicode11Addon } from 'xterm-addon-unicode11';
import { SerializeAddon } from 'xterm-addon-serialize';
import { usePty } from '../hooks/usePty';
import { useStore } from '../store';
import { TerminalStatus } from '../../shared/types';
import { colors } from '../theme/colors';
import { xtermTheme } from '../theme/xterm-theme';

interface TerminalPaneProps {
  terminalId: string;
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

export function TerminalPane({ terminalId }: TerminalPaneProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const termRef = useRef<Terminal | null>(null);
  const fitRef = useRef<FitAddon | null>(null);
  const searchRef = useRef<SearchAddon | null>(null);
  const pty = usePty();
  const entry = useStore((s) => s.terminals[terminalId]);
  const [mounted, setMounted] = useState(false);

  // Initialize xterm with all addons
  useEffect(() => {
    if (!containerRef.current) return;

    const term = new Terminal({
      theme: xtermTheme,
      fontSize: 13,
      fontFamily: "'Menlo', 'Monaco', 'Courier New', monospace",
      lineHeight: 1.2,
      cursorBlink: true,
      cursorStyle: 'bar',
      scrollback: 10000,
      convertEol: true,
      allowProposedApi: true,
      macOptionIsMeta: true,        // Option key works as Meta (for alt shortcuts in shell)
      macOptionClickForcesSelection: true,
      rightClickSelectsWord: true,
      drawBoldTextInBrightColors: true,
      tabStopWidth: 8,
    });

    // Core addon: fit terminal to container
    const fit = new FitAddon();
    term.loadAddon(fit);

    // Search addon: Cmd+F to search within terminal output
    const search = new SearchAddon();
    term.loadAddon(search);

    // Unicode 11: proper emoji and wide character support
    const unicode11 = new Unicode11Addon();
    term.loadAddon(unicode11);
    term.unicode.activeVersion = '11';

    // Serialize: save/restore terminal content
    const serialize = new SerializeAddon();
    term.loadAddon(serialize);

    // Open terminal in container
    term.open(containerRef.current);

    // Using canvas renderer (WebGL addon crashes in Electron on dispose)

    // CRITICAL: Prevent browser from intercepting Tab, arrow keys, etc.
    // All keyboard events should go to the PTY, not the browser
    term.attachCustomKeyEventHandler((event: KeyboardEvent) => {
      // Let Cmd/Ctrl shortcuts through to our app shortcuts handler
      if ((event.metaKey || event.ctrlKey) && !event.altKey) {
        const key = event.key.toLowerCase();
        // These are our app shortcuts — let them bubble up
        if (['k', 'n', 't', 'w', 'd', 'p', ','].includes(key)) return false;
        if (event.shiftKey && ['[', ']', 'p', 'd', 'enter'].includes(key)) return false;
        if (key >= '1' && key <= '9') return false;
        // Cmd+C (copy) and Cmd+V (paste) — let the browser handle these
        if (key === 'c' && term.hasSelection()) return false;
        if (key === 'v') return false;
      }
      // Everything else (including Tab) goes to the terminal
      return true;
    });

    termRef.current = term;
    fitRef.current = fit;
    searchRef.current = search;

    // Fit after the container has rendered
    requestAnimationFrame(() => {
      try { fit.fit(); } catch {}
      setMounted(true);
    });

    // Refit on container resize
    const resizeObserver = new ResizeObserver(() => {
      try { fit.fit(); } catch {}
    });
    resizeObserver.observe(containerRef.current);

    return () => {
      resizeObserver.disconnect();
      term.dispose();
      termRef.current = null;
      fitRef.current = null;
      searchRef.current = null;
      setMounted(false);
    };
  }, []);

  // Wire PTY data once terminal is mounted
  useEffect(() => {
    if (!mounted || !termRef.current) return;

    const term = termRef.current;

    // Receive data from PTY → write to xterm
    const cleanupData = pty.onData((id, data) => {
      if (id === terminalId) {
        term.write(data);
      }
    });

    // User types in xterm → send to PTY
    const inputDisposable = term.onData((data) => {
      pty.write(terminalId, data);
    });

    // Terminal resize → tell PTY
    const resizeDisposable = term.onResize(({ cols, rows }) => {
      pty.resize(terminalId, cols, rows);
    });

    // Sync initial size
    if (fitRef.current) {
      try {
        fitRef.current.fit();
        pty.resize(terminalId, term.cols, term.rows);
      } catch {}
    }

    // Focus the terminal so user can type immediately
    term.focus();

    return () => {
      cleanupData();
      inputDisposable.dispose();
      resizeDisposable.dispose();
    };
  }, [mounted, terminalId]);

  if (!entry) return null;

  const isExited = entry.status === TerminalStatus.EXITED;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: '1 1 0%', overflow: 'hidden' }}>
      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '6px 12px', flexShrink: 0,
        backgroundColor: colors.bg.tertiary, borderBottom: `1px solid ${colors.border.default}`
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ color: colors.accent.primary }}>●</span>
          <span style={{ fontSize: 12, color: colors.text.secondary }}>
            {entry.command} — {entry.cwd}
          </span>
        </div>
        <div style={{ display: 'flex', gap: 12, fontSize: 12, color: colors.text.dim }}>
          <span>Split ⌘D</span>
          <span>Close ⌘W</span>
        </div>
      </div>

      {/* Terminal container — uses absolute positioning to guarantee pixel dimensions for xterm */}
      <div style={{ position: 'relative', flex: '1 1 0%', minHeight: 0 }}>
        <div
          ref={containerRef}
          style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }}
          onClick={() => termRef.current?.focus()}
        />
        {isExited && (
          <div style={{
            position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            backgroundColor: 'rgba(0,0,0,0.6)', zIndex: 10
          }}>
            <div style={{ textAlign: 'center' }}>
              <p style={{ color: colors.text.muted }}>
                Process exited with code {entry.exitCode ?? 'unknown'}
              </p>
              <p style={{ marginTop: 8, fontSize: 12, color: colors.text.dim }}>
                Press any key to close or click Restart
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
