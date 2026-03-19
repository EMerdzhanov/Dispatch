import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

interface QuickLaunchProps {
  onSpawn: (command: string, env?: Record<string, string>) => void;
}

export function QuickLaunch({ onSpawn }: QuickLaunchProps) {
  const presets = useStore((s) => s.presets);

  return (
    <div className="p-2.5 border-b" style={{ borderColor: colors.border.default }}>
      <div className="text-[9px] uppercase tracking-widest mb-1.5" style={{ color: colors.text.dim }}>
        Quick Launch
      </div>
      <div className="flex gap-1 flex-wrap">
        {presets.map((preset) => (
          <button
            key={preset.name}
            className="px-2 py-1 rounded text-[10px] border transition-colors hover:opacity-80"
            style={{
              backgroundColor: colors.bg.tertiary,
              borderColor: colors.border.default,
              color: preset.color,
            }}
            onClick={() => onSpawn(preset.command, preset.env)}
            title={preset.command}
          >
            {preset.name}
          </button>
        ))}
      </div>
    </div>
  );
}
