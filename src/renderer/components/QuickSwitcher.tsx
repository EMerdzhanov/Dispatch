// src/renderer/components/QuickSwitcher.tsx
import React, { useState, useRef, useEffect, useMemo } from 'react';
import Fuse from 'fuse.js';
import { useStore } from '../store';

interface QuickSwitcherProps {
  open: boolean;
  onClose: () => void;
}

interface SwitchItem {
  type: 'group' | 'terminal';
  id: string;
  label: string;
  sublabel?: string;
}

export function QuickSwitcher({ open, onClose }: QuickSwitcherProps) {
  const [query, setQuery] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const groups = useStore((s) => s.groups);
  const terminals = useStore((s) => s.terminals);
  const setActiveGroup = useStore((s) => s.setActiveGroup);
  const setActiveTerminal = useStore((s) => s.setActiveTerminal);

  const items: SwitchItem[] = useMemo(() => {
    const list: SwitchItem[] = [];
    for (const g of groups) {
      list.push({ type: 'group', id: g.id, label: g.label, sublabel: g.cwd });
      for (const tid of g.terminalIds) {
        const t = terminals[tid];
        if (t) list.push({ type: 'terminal', id: tid, label: t.command, sublabel: t.cwd });
      }
    }
    return list;
  }, [groups, terminals]);

  const fuse = useMemo(() => new Fuse(items, { keys: ['label', 'sublabel'], threshold: 0.4 }), [items]);

  const results = query ? fuse.search(query).map((r) => r.item) : items;

  useEffect(() => {
    if (open) {
      setQuery('');
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [open]);

  if (!open) return null;

  const handleSelect = (item: SwitchItem) => {
    if (item.type === 'group') {
      setActiveGroup(item.id);
    } else {
      setActiveTerminal(item.id);
      const group = groups.find((g) => g.terminalIds.includes(item.id));
      if (group) setActiveGroup(group.id);
    }
    onClose();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') onClose();
    else if (e.key === 'Enter' && results.length > 0) handleSelect(results[0]);
  };

  return (
    <div className="d-overlay">
      <div className="d-overlay__backdrop" onClick={onClose} />
      <div className="d-overlay__panel" onClick={(e) => e.stopPropagation()}>
        <input
          ref={inputRef}
          type="text"
          placeholder="Switch to..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          className="d-overlay__input"
        />
        <div className="d-overlay__list">
          {results.map((item) => (
            <button
              key={`${item.type}-${item.id}`}
              className="d-overlay__item"
              onClick={() => handleSelect(item)}
            >
              <span className="d-overlay__item-type">
                {item.type === 'group' ? 'Project' : 'Term'}
              </span>
              <div>
                <div className="d-overlay__item-label">{item.label}</div>
                {item.sublabel && (
                  <div className="d-overlay__item-sublabel">{item.sublabel}</div>
                )}
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
