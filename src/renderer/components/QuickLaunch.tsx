import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

interface QuickLaunchProps {
  onSpawn: (command: string, env?: Record<string, string>) => void;
}

export function QuickLaunch({ onSpawn }: QuickLaunchProps) {
  const presets = useStore((s) => s.presets);

  return (
    <div style={{ padding: '10px 10px 8px', borderBottom: `1px solid ${colors.border.subtle}` }}>
      <div style={{
        fontSize: 9, textTransform: 'uppercase', letterSpacing: '0.12em',
        marginBottom: 8, color: colors.text.dim,
      }}>
        Quick Launch
      </div>
      <div style={{
        display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6,
      }}>
        {presets.map((preset) => (
          <button
            key={preset.name}
            style={{
              display: 'flex', alignItems: 'center', gap: 7,
              padding: '5px 8px',
              borderRadius: 5,
              border: 'none',
              borderLeft: `2px solid ${preset.color}`,
              backgroundColor: colors.bg.elevated,
              cursor: 'pointer',
              textAlign: 'left',
              transition: 'background-color 0.12s',
            }}
            onClick={() => onSpawn(preset.command, preset.env)}
            title={preset.command}
            onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#1e2a3a')}
            onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = colors.bg.elevated)}
          >
            <span style={{ fontSize: 7, color: preset.color, lineHeight: 1 }}>●</span>
            <span style={{ fontSize: 10, color: colors.text.secondary, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {preset.name}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}
