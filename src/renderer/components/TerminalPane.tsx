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

function LastBrowserButton() {
  const lastUrl = useStore((s) => s.lastBrowserUrl);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const addBrowserTab = useStore((s) => s.addBrowserTab);

  if (!lastUrl) return null;

  let host = lastUrl;
  try { host = new URL(lastUrl).host; } catch {}

  return (
    <button
      onClick={() => {
        if (!activeGroupId) return;
        const tab = { id: crypto.randomUUID(), url: lastUrl, title: host };
        addBrowserTab(activeGroupId, tab);
      }}
      title={`Reopen ${lastUrl}`}
      style={{ color: 'var(--accent-blue-light)', cursor: 'pointer', fontSize: 10 }}
    >
      🌐 {host}
    </button>
  );
}

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
  const resyncingRef = useRef(false);

  // Initialize xterm with all addons
  useEffect(() => {
    if (!containerRef.current) return;

    const settings = useStore.getState().settings;

    const term = new Terminal({
      theme: xtermTheme,
      fontSize: settings.fontSize || 13,
      fontFamily: settings.fontFamily || "'JetBrains Mono', 'Fira Code', 'SF Mono', Menlo, Monaco, 'Courier New', monospace",
      lineHeight: settings.lineHeight || 1.2,
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
      // Ctrl+Tab: cycle terminals — always let the app handle it
      if (event.ctrlKey && event.key === 'Tab') return false;

      if ((event.metaKey || event.ctrlKey) && !event.altKey) {
        const key = event.key.toLowerCase();
        if (['k', 'n', 't', 'w', 'd', 'p', ','].includes(key)) return false;
        if (event.shiftKey && ['[', ']', 'p', 'd', 'enter', '/'].includes(key)) return false;
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
      try {
        fit.fit();
        pty.resize(terminalId, term.cols, term.rows);
      } catch {}
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
      if (id === terminalId && !resyncingRef.current) {
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

  // Force tmux to redraw when this terminal becomes active by sending two
  // resize calls in separate event loop ticks: shrink by 1 col then restore.
  // Data writes are suppressed during the cycle to prevent flicker.
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const activeGroupId = useStore((s) => s.activeGroupId);
  useEffect(() => {
    if (activeTerminalId !== terminalId || !mounted || !termRef.current || !fitRef.current) return;
    const term = termRef.current;
    const fit = fitRef.current;
    const timers: ReturnType<typeof setTimeout>[] = [];

    const doResync = () => {
      try { fit.fit(); } catch {}
      const cols = term.cols;
      const rows = term.rows;
      resyncingRef.current = true;
      pty.resize(terminalId, Math.max(1, cols - 1), rows);
      const inner = setTimeout(() => {
        pty.resize(terminalId, cols, rows);
        resyncingRef.current = false;
        try { term.refresh(0, term.rows - 1); term.focus(); } catch {}
      }, 16);
      timers.push(inner);
    };

    doResync();
    // Retry for freshly attached tmux sessions that need init time
    timers.push(setTimeout(doResync, 500));
    return () => {
      timers.forEach(clearTimeout);
      resyncingRef.current = false;
    };
  }, [activeTerminalId, activeGroupId, mounted, terminalId]);

  if (!entry) return null;

  const isExited = entry.status === TerminalStatus.EXITED;
  const isClaude = entry.command === 'claude' || entry.command.startsWith('claude ');

  // Dot color: blue for claude, green for shell
  const dotColor = isClaude ? '#53a8ff' : '#4caf50';

  // Short command label (first word)
  const shortCommand = entry.command.split(' ')[0].split('/').pop() || entry.command;

  // Use custom label if set, otherwise command + folder
  const folder = folderName(entry.cwd);
  const headerLabel = entry.label
    ? `${entry.label} — ${folder}`
    : `${shortCommand}${folder ? ` — ${folder}` : ''}`;
  const headerTooltip = `${entry.label || entry.command} — ${entry.cwd}`;

  return (
    <div className="d-termpane">
      {/* Header */}
      <div className="d-termpane__header">
        <div className="d-termpane__header-left" title={headerTooltip}>
          <span className="d-termpane__dot" style={{ color: dotColor }}>●</span>
          <span className="d-termpane__title">{headerLabel}</span>
        </div>
        <div className="d-termpane__shortcuts">
          <LastBrowserButton />
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
