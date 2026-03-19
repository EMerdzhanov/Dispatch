import { useEffect } from 'react';
import { useStore } from '../store';

interface ShortcutHandlers {
  onNewTerminal: () => void;
  onNewTab: () => void;
  onCloseTerminal: () => void;
  onOpenSearch: () => void;
  onOpenPalette: () => void;
  onSplitHorizontal: () => void;
  onSplitVertical: () => void;
  onToggleZenMode: () => void;
  onOpenSettings: () => void;
  onMovePaneFocus: (direction: 'up' | 'down' | 'left' | 'right') => void;
}

export function useShortcuts(handlers: ShortcutHandlers) {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const setActiveGroup = useStore((s) => s.setActiveGroup);
  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const terminalIds = activeGroup?.terminalIds ?? [];
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const setActiveTerminal = useStore((s) => s.setActiveTerminal);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const meta = e.metaKey || e.ctrlKey;

      if (meta && e.key === 'n' && !e.shiftKey) {
        e.preventDefault();
        handlers.onNewTerminal();
        return;
      }

      if (meta && e.key === 't') {
        e.preventDefault();
        handlers.onNewTab();
        return;
      }

      if (meta && e.key === 'w') {
        e.preventDefault();
        handlers.onCloseTerminal();
        return;
      }

      if (meta && e.key === 'k') {
        e.preventDefault();
        handlers.onOpenSearch();
        return;
      }

      if (meta && e.shiftKey && (e.key === 'p' || e.key === 'P')) {
        e.preventDefault();
        handlers.onOpenPalette();
        return;
      }

      if (meta && e.key >= '1' && e.key <= '9') {
        e.preventDefault();
        const index = parseInt(e.key, 10) - 1;
        if (groups[index]) {
          setActiveGroup(groups[index].id);
        }
        return;
      }

      if (meta && e.shiftKey && (e.key === ']' || e.key === '[')) {
        e.preventDefault();
        const currentIndex = groups.findIndex((g) => g.id === activeGroupId);
        const next = e.key === ']'
          ? (currentIndex + 1) % groups.length
          : (currentIndex - 1 + groups.length) % groups.length;
        if (groups[next]) setActiveGroup(groups[next].id);
        return;
      }

      if (e.ctrlKey && e.key === 'Tab') {
        e.preventDefault();
        if (terminalIds.length > 0) {
          const currentIndex = terminalIds.indexOf(activeTerminalId || '');
          const next = (currentIndex + 1) % terminalIds.length;
          setActiveTerminal(terminalIds[next]);
        }
        return;
      }

      if (meta && e.key === 'd' && !e.shiftKey) {
        e.preventDefault();
        handlers.onSplitHorizontal();
        return;
      }

      if (meta && e.shiftKey && (e.key === 'd' || e.key === 'D')) {
        e.preventDefault();
        handlers.onSplitVertical();
        return;
      }

      if (meta && e.shiftKey && e.key === 'Enter') {
        e.preventDefault();
        handlers.onToggleZenMode();
        return;
      }

      if (meta && e.key === ',') {
        e.preventDefault();
        handlers.onOpenSettings();
        return;
      }

      if (meta && e.altKey && ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) {
        e.preventDefault();
        handlers.onMovePaneFocus(e.key.replace('Arrow', '').toLowerCase() as 'up' | 'down' | 'left' | 'right');
        return;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [groups, activeGroupId, terminalIds, activeTerminalId, handlers]);
}
