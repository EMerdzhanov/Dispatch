// src/renderer/components/QuickSwitcher.tsx
import React, { useState, useRef, useEffect, useMemo } from 'react';
import Fuse from 'fuse.js';
import { useStore } from '../store';
import { colors } from '../theme/colors';

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
    <div className="fixed inset-0 z-50 flex items-start justify-center pt-24" onClick={onClose}>
      <div
        className="w-[500px] rounded-lg shadow-2xl border overflow-hidden"
        style={{ backgroundColor: colors.bg.tertiary, borderColor: colors.border.default }}
        onClick={(e) => e.stopPropagation()}
      >
        <input
          ref={inputRef}
          type="text"
          placeholder="Switch to..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          className="w-full px-4 py-3 text-sm border-b outline-none"
          style={{
            backgroundColor: colors.bg.tertiary,
            borderColor: colors.border.default,
            color: colors.text.primary,
          }}
        />
        <div className="max-h-64 overflow-y-auto">
          {results.map((item) => (
            <button
              key={`${item.type}-${item.id}`}
              className="w-full px-4 py-2.5 flex items-center gap-3 text-left transition-colors"
              onClick={() => handleSelect(item)}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.bg.elevated)}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
            >
              <span className="text-[10px] uppercase w-14" style={{ color: colors.text.dim }}>
                {item.type === 'group' ? 'Project' : 'Term'}
              </span>
              <div>
                <div className="text-sm" style={{ color: colors.text.primary }}>{item.label}</div>
                {item.sublabel && (
                  <div className="text-xs" style={{ color: colors.text.dim }}>{item.sublabel}</div>
                )}
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
