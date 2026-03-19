// src/renderer/components/CommandPalette.tsx
import React, { useState, useRef, useEffect, useMemo } from 'react';
import Fuse from 'fuse.js';
import { useStore } from '../store';
import { colors } from '../theme/colors';
import type { Preset } from '../../shared/types';

interface CommandPaletteProps {
  open: boolean;
  onClose: () => void;
  onSpawn: (command: string, env?: Record<string, string>) => void;
}

export function CommandPalette({ open, onClose, onSpawn }: CommandPaletteProps) {
  const [query, setQuery] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const presets = useStore((s) => s.presets);

  const fuse = useMemo(() => new Fuse(presets, { keys: ['name', 'command'], threshold: 0.4 }), [presets]);

  const results: Preset[] = query
    ? fuse.search(query).map((r) => r.item)
    : presets;

  useEffect(() => {
    if (open) {
      setQuery('');
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [open]);

  if (!open) return null;

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      onClose();
    } else if (e.key === 'Enter' && results.length > 0) {
      onSpawn(results[0].command, results[0].env);
      onClose();
    }
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
          placeholder="Search presets and actions..."
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
          {results.map((preset) => (
            <button
              key={preset.name}
              className="w-full px-4 py-2.5 flex items-center gap-3 text-left hover:opacity-80 transition-colors"
              style={{ backgroundColor: 'transparent' }}
              onClick={() => { onSpawn(preset.command, preset.env); onClose(); }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = colors.bg.elevated)}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
            >
              <span className="w-2 h-2 rounded-full" style={{ backgroundColor: preset.color }} />
              <div>
                <div className="text-sm" style={{ color: colors.text.primary }}>{preset.name}</div>
                <div className="text-xs" style={{ color: colors.text.dim }}>{preset.command}</div>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
