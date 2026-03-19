// src/renderer/components/SettingsPanel.tsx
import React from 'react';
import { useStore } from '../store';

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
    <div className="d-overlay d-overlay--center">
      <div className="d-overlay__backdrop" onClick={onClose} />
      <div className="d-overlay__panel d-overlay__panel--wide" onClick={(e) => e.stopPropagation()}>
        <div className="d-settings__header">
          <h2 className="d-settings__title">Settings</h2>
          <button onClick={onClose} className="d-settings__close">Close (Esc)</button>
        </div>

        {/* Terminal section */}
        <div className="d-settings__section">
          <h3 className="d-settings__section-title">Terminal</h3>
          <label className="d-settings__row">
            <span className="d-settings__label">Font Family</span>
            <input
              type="text"
              value={settings.fontFamily}
              onChange={(e) => setSettings({ ...settings, fontFamily: e.target.value })}
              className="d-settings__input d-settings__input--wide"
            />
          </label>
          <label className="d-settings__row">
            <span className="d-settings__label">Font Size</span>
            <input
              type="number"
              value={settings.fontSize}
              onChange={(e) => setSettings({ ...settings, fontSize: parseInt(e.target.value, 10) || 13 })}
              className="d-settings__input d-settings__input--narrow"
            />
          </label>
          <label className="d-settings__row">
            <span className="d-settings__label">Line Height</span>
            <input
              type="number"
              step="0.1"
              value={settings.lineHeight}
              onChange={(e) => setSettings({ ...settings, lineHeight: parseFloat(e.target.value) || 1.2 })}
              className="d-settings__input d-settings__input--narrow"
            />
          </label>
          <label className="d-settings__row">
            <span className="d-settings__label">Default Shell</span>
            <input
              type="text"
              value={settings.shell}
              onChange={(e) => setSettings({ ...settings, shell: e.target.value })}
              className="d-settings__input d-settings__input--wide"
            />
          </label>
          <label className="d-settings__row">
            <span className="d-settings__label">Scan Interval (ms)</span>
            <input
              type="number"
              step="1000"
              value={settings.scanInterval}
              onChange={(e) => setSettings({ ...settings, scanInterval: parseInt(e.target.value, 10) || 10000 })}
              className="d-settings__input d-settings__input--narrow"
            />
          </label>
        </div>

        {/* Presets section */}
        <div className="d-settings__section">
          <h3 className="d-settings__section-title">Presets</h3>
          {presets.map((preset, i) => (
            <div key={i} className="d-settings__preset">
              <span className="d-settings__preset-dot" style={{ backgroundColor: preset.color }} />
              <div>
                <div className="d-settings__preset-name">{preset.name}</div>
                <div className="d-settings__preset-command">{preset.command}</div>
              </div>
              <button
                className="d-settings__preset-remove"
                onClick={() => setPresets(presets.filter((_, j) => j !== i))}
              >
                Remove
              </button>
            </div>
          ))}
          <button
            className="d-settings__add-btn"
            onClick={() => setPresets([...presets, { name: 'New Preset', command: '', color: '#888', icon: 'terminal' }])}
          >
            + Add Preset
          </button>
        </div>
      </div>
    </div>
  );
}
