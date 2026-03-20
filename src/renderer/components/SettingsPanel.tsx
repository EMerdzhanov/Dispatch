import React, { useState } from 'react';
import { useStore } from '../store';
import type { Preset, Settings } from '../../shared/types';

interface SettingsPanelProps {
  open: boolean;
  onClose: () => void;
}

// Shell is always present and can't be removed
const SHELL_PRESET: Preset = { name: 'Shell', command: '$SHELL', color: '#888888', icon: 'terminal' };

const PRESET_COLORS = ['#0f3460', '#e94560', '#f5a623', '#4caf50', '#53a8ff', '#c678dd', '#56b6c2', '#888888'];

export function SettingsPanel({ open, onClose }: SettingsPanelProps) {
  const settings = useStore((s) => s.settings);
  const setSettings = useStore((s) => s.setSettings);
  const presets = useStore((s) => s.presets);
  const setPresets = useStore((s) => s.setPresets);
  const templates = useStore((s) => s.templates);
  const setTemplates = useStore((s) => s.setTemplates);
  const persistSettings = (updated: Settings) => {
    setSettings(updated);
    (window as any).dispatch?.state?.saveSettings(updated);
  };

  const [editingIdx, setEditingIdx] = useState<number | null>(null);
  const [editName, setEditName] = useState('');
  const [editCommand, setEditCommand] = useState('');
  const [editColor, setEditColor] = useState('#888888');

  if (!open) return null;

  // Separate Shell (permanent) from user presets
  const userPresets = presets.filter((p) => p.command !== '$SHELL');
  const hasShell = presets.some((p) => p.command === '$SHELL');

  const startEdit = (preset: Preset, idx: number) => {
    setEditingIdx(idx);
    setEditName(preset.name);
    setEditCommand(preset.command);
    setEditColor(preset.color);
  };

  const saveEdit = () => {
    if (editingIdx === null || !editName.trim() || !editCommand.trim()) return;
    const updated = [...presets];
    updated[editingIdx] = { ...updated[editingIdx], name: editName.trim(), command: editCommand.trim(), color: editColor };
    setPresets(updated);
    setEditingIdx(null);
  };

  const addPreset = () => {
    const newPreset: Preset = { name: 'New Preset', command: 'claude', color: '#53a8ff', icon: 'terminal' };
    // Insert before Shell (Shell stays last)
    const shellIdx = presets.findIndex((p) => p.command === '$SHELL');
    const updated = [...presets];
    if (shellIdx >= 0) {
      updated.splice(shellIdx, 0, newPreset);
    } else {
      updated.push(newPreset);
    }
    setPresets(updated);
    startEdit(newPreset, shellIdx >= 0 ? shellIdx : updated.length - 1);
  };

  const removePreset = (idx: number) => {
    setPresets(presets.filter((_, i) => i !== idx));
    if (editingIdx === idx) setEditingIdx(null);
  };

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
              onChange={(e) => persistSettings({ ...settings, fontFamily: e.target.value })}
              className="d-settings__input d-settings__input--wide"
            />
          </label>
          <label className="d-settings__row">
            <span className="d-settings__label">Font Size</span>
            <input
              type="number"
              value={settings.fontSize}
              onChange={(e) => persistSettings({ ...settings, fontSize: parseInt(e.target.value, 10) || 13 })}
              className="d-settings__input d-settings__input--narrow"
            />
          </label>
          <label className="d-settings__row">
            <span className="d-settings__label">Line Height</span>
            <input
              type="number"
              step="0.1"
              value={settings.lineHeight}
              onChange={(e) => persistSettings({ ...settings, lineHeight: parseFloat(e.target.value) || 1.2 })}
              className="d-settings__input d-settings__input--narrow"
            />
          </label>
          <label className="d-settings__row">
            <span className="d-settings__label">Default Shell</span>
            <input
              type="text"
              value={settings.shell}
              onChange={(e) => persistSettings({ ...settings, shell: e.target.value })}
              className="d-settings__input d-settings__input--wide"
            />
          </label>
        </div>

        {/* Notifications section */}
        <div className="d-settings__section">
          <h3 className="d-settings__section-title">Notifications</h3>
          <label className="d-settings__row">
            <span className="d-settings__label">Desktop Notifications</span>
            <input
              type="checkbox"
              checked={settings.notificationsEnabled}
              onChange={(e) => persistSettings({ ...settings, notificationsEnabled: e.target.checked })}
            />
          </label>
          <label className="d-settings__row">
            <span className="d-settings__label">Sound Effects</span>
            <input
              type="checkbox"
              checked={settings.soundEnabled}
              onChange={(e) => persistSettings({ ...settings, soundEnabled: e.target.checked })}
            />
          </label>
        </div>

        {/* Quick Launch Presets section */}
        <div className="d-settings__section">
          <h3 className="d-settings__section-title">Quick Launch Presets</h3>

          {presets.map((preset, i) => {
            const isShell = preset.command === '$SHELL';
            const isEditing = editingIdx === i;

            if (isEditing) {
              return (
                <div key={i} className="d-settings__preset" style={{ flexDirection: 'column', gap: 8, alignItems: 'stretch' }}>
                  <div className="d-settings__row">
                    <span className="d-settings__label">Name</span>
                    <input
                      className="d-settings__input d-settings__input--wide"
                      value={editName}
                      onChange={(e) => setEditName(e.target.value)}
                      onKeyDown={(e) => { if (e.key === 'Enter') saveEdit(); if (e.key === 'Escape') setEditingIdx(null); }}
                      autoFocus
                    />
                  </div>
                  <div className="d-settings__row">
                    <span className="d-settings__label">Command</span>
                    <input
                      className="d-settings__input d-settings__input--wide"
                      value={editCommand}
                      onChange={(e) => setEditCommand(e.target.value)}
                      onKeyDown={(e) => { if (e.key === 'Enter') saveEdit(); if (e.key === 'Escape') setEditingIdx(null); }}
                      placeholder="e.g. claude --resume"
                    />
                  </div>
                  <div className="d-settings__row">
                    <span className="d-settings__label">Color</span>
                    <div style={{ display: 'flex', gap: 4 }}>
                      {PRESET_COLORS.map((c) => (
                        <button
                          key={c}
                          onClick={() => setEditColor(c)}
                          style={{
                            width: 18, height: 18, borderRadius: '50%', border: 'none',
                            backgroundColor: c, cursor: 'pointer',
                            outline: editColor === c ? '2px solid var(--text-primary)' : 'none',
                            outlineOffset: 2,
                          }}
                        />
                      ))}
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                    <button className="d-context-menu__item" style={{ padding: '4px 12px' }} onClick={() => setEditingIdx(null)}>Cancel</button>
                    <button className="d-welcome__button" style={{ padding: '4px 12px', fontSize: 11 }} onClick={saveEdit}>Save</button>
                  </div>
                </div>
              );
            }

            return (
              <div key={i} className="d-settings__preset">
                <span className="d-settings__preset-dot" style={{ backgroundColor: preset.color }} />
                <div style={{ flex: 1 }}>
                  <div className="d-settings__preset-name">{preset.name}</div>
                  <div className="d-settings__preset-command">{preset.command}</div>
                </div>
                {isShell ? (
                  <span style={{ fontSize: 9, color: 'var(--text-dim)' }}>default</span>
                ) : (
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button className="d-settings__preset-remove" style={{ color: 'var(--text-muted)' }} onClick={() => startEdit(preset, i)}>Edit</button>
                    <button className="d-settings__preset-remove" onClick={() => removePreset(i)}>Remove</button>
                  </div>
                )}
              </div>
            );
          })}

          <button className="d-settings__add-btn" onClick={addPreset}>
            + Add Preset
          </button>
        </div>

        {/* Templates section */}
        {templates.length > 0 && (
          <div className="d-settings__section">
            <h3 className="d-settings__section-title">Saved Templates</h3>
            {templates.map((t, i) => (
              <div key={i} className="d-settings__preset">
                <span className="d-settings__preset-dot" style={{ backgroundColor: 'var(--accent-blue-light)' }} />
                <div style={{ flex: 1 }}>
                  <div className="d-settings__preset-name">{t.name}</div>
                  <div className="d-settings__preset-command">{t.cwd}</div>
                </div>
                <button
                  className="d-settings__preset-remove"
                  onClick={() => {
                    const updated = templates.filter((_, j) => j !== i);
                    setTemplates(updated);
                    (window as any).dispatch?.templates?.save(updated);
                  }}
                >
                  Remove
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
