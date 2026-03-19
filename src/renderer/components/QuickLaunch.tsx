import React from 'react';
import { useStore } from '../store';

interface QuickLaunchProps {
  onSpawn: (command: string, env?: Record<string, string>) => void;
}

export function QuickLaunch({ onSpawn }: QuickLaunchProps) {
  const presets = useStore((s) => s.presets);

  return (
    <div className="d-quicklaunch">
      <div className="d-quicklaunch__label">Quick Launch</div>
      <div className="d-quicklaunch__grid">
        {presets.map((preset) => (
          <button
            key={preset.name}
            className="d-preset-btn"
            style={{ borderLeftColor: preset.color }}
            onClick={() => onSpawn(preset.command, preset.env)}
            title={preset.command}
          >
            <span className="d-preset-btn__dot" style={{ backgroundColor: preset.color }} />
            {preset.name}
          </button>
        ))}
      </div>
    </div>
  );
}
