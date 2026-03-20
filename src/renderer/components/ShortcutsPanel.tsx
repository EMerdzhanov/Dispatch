import React from 'react';

interface ShortcutsPanelProps {
  open: boolean;
  onClose: () => void;
}

const SHORTCUTS = [
  { category: 'General', items: [
    { keys: '⌘ ,', action: 'Open Settings' },
    { keys: '⌘ ?', action: 'Keyboard Shortcuts' },
  ]},
  { category: 'Terminals', items: [
    { keys: '⌘ N', action: 'New Terminal' },
    { keys: '⌘ W', action: 'Close Split View' },
    { keys: 'Ctrl Tab', action: 'Cycle Terminals' },
  ]},
  { category: 'Tabs & Navigation', items: [
    { keys: '⌘ T', action: 'Open Project Folder' },
    { keys: '⌘ 1-9', action: 'Switch to Tab' },
    { keys: '⌘ ⇧ [', action: 'Previous Tab' },
    { keys: '⌘ ⇧ ]', action: 'Next Tab' },
  ]},
  { category: 'Layout', items: [
    { keys: '⌘ D', action: 'Split Horizontal' },
    { keys: '⌘ ⇧ D', action: 'Split Vertical' },
    { keys: '⌘ ⇧ Enter', action: 'Toggle Zen Mode' },
  ]},
  { category: 'Tools', items: [
    { keys: '⌘ K', action: 'Quick Switcher' },
    { keys: '⌘ ⇧ P', action: 'Command Palette' },
    { keys: '⌘ ⇧ S', action: 'Save Template' },
  ]},
];

export function ShortcutsPanel({ open, onClose }: ShortcutsPanelProps) {
  if (!open) return null;

  return (
    <div className="d-overlay d-overlay--center" onClick={onClose}>
      <div className="d-overlay__backdrop" />
      <div className="d-overlay__panel d-overlay__panel--wide" onClick={(e) => e.stopPropagation()}>
        <div className="d-settings__header">
          <h2 className="d-settings__title">Keyboard Shortcuts</h2>
          <button onClick={onClose} className="d-settings__close">Close (Esc)</button>
        </div>
        {SHORTCUTS.map((section) => (
          <div key={section.category} className="d-settings__section">
            <h3 className="d-settings__section-title">{section.category}</h3>
            {section.items.map((shortcut) => (
              <div key={shortcut.action} className="d-settings__row">
                <span className="d-settings__label">{shortcut.action}</span>
                <kbd className="d-shortcut-key">{shortcut.keys}</kbd>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
