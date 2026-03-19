// src/renderer/components/SettingsPanel.tsx
import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

interface SettingsPanelProps {
  open: boolean;
  onClose: () => void;
}

export function SettingsPanel({ open, onClose }: SettingsPanelProps) {
  const settings = useStore((s) => s.settings);
  const setSettings = useStore((s) => s.setSettings);
  const presets = useStore((s) => s.presets);
  const setPresets = useStore((s) => s.setPresets);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center" onClick={onClose}>
      <div
        className="w-[600px] max-h-[80vh] rounded-lg shadow-2xl border overflow-y-auto"
        style={{ backgroundColor: colors.bg.tertiary, borderColor: colors.border.default }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b" style={{ borderColor: colors.border.default }}>
          <h2 className="text-sm font-medium" style={{ color: colors.text.primary }}>Settings</h2>
          <button onClick={onClose} className="text-xs" style={{ color: colors.text.dim }}>Close (Esc)</button>
        </div>

        {/* Terminal section */}
        <div className="px-6 py-4 border-b" style={{ borderColor: colors.border.default }}>
          <h3 className="text-xs uppercase tracking-widest mb-3" style={{ color: colors.text.dim }}>Terminal</h3>
          <div className="space-y-3">
            <label className="flex items-center justify-between">
              <span className="text-sm" style={{ color: colors.text.secondary }}>Font Family</span>
              <input
                type="text"
                value={settings.fontFamily}
                onChange={(e) => setSettings({ ...settings, fontFamily: e.target.value })}
                className="w-48 px-2 py-1 rounded text-xs border outline-none"
                style={{ backgroundColor: colors.bg.primary, borderColor: colors.border.default, color: colors.text.primary }}
              />
            </label>
            <label className="flex items-center justify-between">
              <span className="text-sm" style={{ color: colors.text.secondary }}>Font Size</span>
              <input
                type="number"
                value={settings.fontSize}
                onChange={(e) => setSettings({ ...settings, fontSize: parseInt(e.target.value, 10) || 13 })}
                className="w-20 px-2 py-1 rounded text-xs border outline-none"
                style={{ backgroundColor: colors.bg.primary, borderColor: colors.border.default, color: colors.text.primary }}
              />
            </label>
            <label className="flex items-center justify-between">
              <span className="text-sm" style={{ color: colors.text.secondary }}>Line Height</span>
              <input
                type="number"
                step="0.1"
                value={settings.lineHeight}
                onChange={(e) => setSettings({ ...settings, lineHeight: parseFloat(e.target.value) || 1.2 })}
                className="w-20 px-2 py-1 rounded text-xs border outline-none"
                style={{ backgroundColor: colors.bg.primary, borderColor: colors.border.default, color: colors.text.primary }}
              />
            </label>
            <label className="flex items-center justify-between">
              <span className="text-sm" style={{ color: colors.text.secondary }}>Default Shell</span>
              <input
                type="text"
                value={settings.shell}
                onChange={(e) => setSettings({ ...settings, shell: e.target.value })}
                className="w-48 px-2 py-1 rounded text-xs border outline-none"
                style={{ backgroundColor: colors.bg.primary, borderColor: colors.border.default, color: colors.text.primary }}
              />
            </label>
            <label className="flex items-center justify-between">
              <span className="text-sm" style={{ color: colors.text.secondary }}>Scan Interval (ms)</span>
              <input
                type="number"
                step="1000"
                value={settings.scanInterval}
                onChange={(e) => setSettings({ ...settings, scanInterval: parseInt(e.target.value, 10) || 10000 })}
                className="w-24 px-2 py-1 rounded text-xs border outline-none"
                style={{ backgroundColor: colors.bg.primary, borderColor: colors.border.default, color: colors.text.primary }}
              />
            </label>
          </div>
        </div>

        {/* Presets section */}
        <div className="px-6 py-4">
          <h3 className="text-xs uppercase tracking-widest mb-3" style={{ color: colors.text.dim }}>Presets</h3>
          <div className="space-y-2">
            {presets.map((preset, i) => (
              <div key={i} className="flex items-center gap-3 p-2 rounded" style={{ backgroundColor: colors.bg.primary }}>
                <span className="w-3 h-3 rounded-full shrink-0" style={{ backgroundColor: preset.color }} />
                <div className="flex-1">
                  <div className="text-sm" style={{ color: colors.text.primary }}>{preset.name}</div>
                  <div className="text-xs" style={{ color: colors.text.dim }}>{preset.command}</div>
                </div>
                <button
                  className="text-xs px-2 py-1 rounded"
                  style={{ color: colors.accent.primary }}
                  onClick={() => setPresets(presets.filter((_, j) => j !== i))}
                >
                  Remove
                </button>
              </div>
            ))}
            <button
              className="w-full py-2 rounded text-xs border border-dashed"
              style={{ borderColor: colors.border.default, color: colors.text.dim }}
              onClick={() => setPresets([...presets, { name: 'New Preset', command: '', color: '#888', icon: 'terminal' }])}
            >
              + Add Preset
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
