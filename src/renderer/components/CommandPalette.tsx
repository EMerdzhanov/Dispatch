// src/renderer/components/CommandPalette.tsx
import React, { useState, useRef, useEffect, useMemo } from 'react';
import Fuse from 'fuse.js';
import { useStore } from '../store';
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
    <div className="d-overlay">
      <div className="d-overlay__backdrop" onClick={onClose} />
      <div className="d-overlay__panel" onClick={(e) => e.stopPropagation()}>
        <input
          ref={inputRef}
          type="text"
          placeholder="Search presets and actions..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          className="d-overlay__input"
        />
        <div className="d-overlay__list">
          {results.map((preset) => (
            <button
              key={preset.name}
              className="d-overlay__item"
              onClick={() => { onSpawn(preset.command, preset.env); onClose(); }}
            >
              <span className="d-overlay__item-dot" style={{ backgroundColor: preset.color }} />
              <div>
                <div className="d-overlay__item-label">{preset.name}</div>
                <div className="d-overlay__item-sublabel">{preset.command}</div>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
