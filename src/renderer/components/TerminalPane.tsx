import React, { useRef, useEffect, useState } from 'react';
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import { SearchAddon } from 'xterm-addon-search';
import { Unicode11Addon } from 'xterm-addon-unicode11';
import { SerializeAddon } from 'xterm-addon-serialize';
import { usePty } from '../hooks/usePty';
import { useStore } from '../store';
import { TerminalStatus } from '../../shared/types';
import { xtermTheme } from '../theme/xterm-theme';

interface TerminalPaneProps {
  terminalId: string;
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

/** Extract the last path segment (folder name) from a full path */
function folderName(cwd: string): string {
  if (!cwd) return '';
  const parts = cwd.replace(/\/$/, '').split('/');
  return parts[parts.length - 1] || cwd;
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
      fontFamily: "'JetBrains Mono', 'Fira Code', 'SF Mono', Menlo, Monaco, 'Courier New', monospace",
      lineHeight: 1.2,
      cursorBlink: true,
      cursorStyle: 'bar',
      scrollback: 10000,
      convertEol: true,
      allowProposedApi: true,
      macOptionIsMeta: true,
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

    // CRITICAL: Prevent browser from intercepting Tab, arrow keys, etc.
    term.attachCustomKeyEventHandler((event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && !event.altKey) {
        const key = event.key.toLowerCase();
        if (['k', 'n', 't', 'w', 'd', 'p', ','].includes(key)) return false;
        if (event.shiftKey && ['[', ']', 'p', 'd', 'enter'].includes(key)) return false;
        if (key >= '1' && key <= '9') return false;
        if (key === 'c' && term.hasSelection()) return false;
        if (key === 'v') return false;
      }
      return true;
    });

    termRef.current = term;
    fitRef.current = fit;
    searchRef.current = search;

    requestAnimationFrame(() => {
      try { fit.fit(); } catch {}
      setMounted(true);
    });

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

    const cleanupData = pty.onData((id, data) => {
      if (id === terminalId) {
        term.write(data);
      }
    });

    const inputDisposable = term.onData((data) => {
      pty.write(terminalId, data);
    });

    const resizeDisposable = term.onResize(({ cols, rows }) => {
      pty.resize(terminalId, cols, rows);
    });

    if (fitRef.current) {
      try {
        fitRef.current.fit();
        pty.resize(terminalId, term.cols, term.rows);
      } catch {}
    }

    term.focus();

    return () => {
      cleanupData();
      inputDisposable.dispose();
      resizeDisposable.dispose();
    };
  }, [mounted, terminalId]);

  if (!entry) return null;

  const isExited = entry.status === TerminalStatus.EXITED;
  const isClaude = entry.command === 'claude' || entry.command.startsWith('claude ');

  // Dot color: blue for claude, green for shell
  const dotColor = isClaude ? '#53a8ff' : '#4caf50';

  // Short command label (first word)
  const shortCommand = entry.command.split(' ')[0].split('/').pop() || entry.command;

  // Folder name only for display; full path in title tooltip
  const folder = folderName(entry.cwd);
  const headerLabel = `${shortCommand}${folder ? ` — ${folder}` : ''}`;
  const headerTooltip = `${entry.command} — ${entry.cwd}`;

  return (
    <div className="d-termpane">
      {/* Header */}
      <div className="d-termpane__header">
        <div className="d-termpane__header-left" title={headerTooltip}>
          <span className="d-termpane__dot" style={{ color: dotColor }}>●</span>
          <span className="d-termpane__title">{headerLabel}</span>
        </div>
        <div className="d-termpane__shortcuts">
          <span>Split ⌘D</span>
          <span>Close ⌘W</span>
        </div>
      </div>

      {/* Terminal container */}
      <div className="d-termpane__container">
        <div
          ref={containerRef}
          className="d-termpane__xterm"
          onClick={() => termRef.current?.focus()}
        />
        {isExited && (
          <div className="d-termpane__exit-overlay">
            <div className="d-termpane__exit-text">
              <p>Process exited with code {entry.exitCode ?? 'unknown'}</p>
              <p className="d-termpane__exit-hint">Press any key to close or click Restart</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
