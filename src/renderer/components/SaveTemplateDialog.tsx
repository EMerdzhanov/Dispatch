import React, { useState, useRef, useEffect } from 'react';

interface SaveTemplateDialogProps {
  open: boolean;
  defaultName: string;
  onSave: (name: string) => void;
  onClose: () => void;
}

export function SaveTemplateDialog({ open, defaultName, onSave, onClose }: SaveTemplateDialogProps) {
  const [name, setName] = useState(defaultName);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (open) {
      setName(defaultName);
      setTimeout(() => inputRef.current?.select(), 50);
    }
  }, [open, defaultName]);

  if (!open) return null;

  return (
    <div className="d-overlay d-overlay--center" onClick={onClose}>
      <div className="d-overlay__backdrop" />
      <div className="d-overlay__panel" onClick={(e) => e.stopPropagation()} style={{ width: 400 }}>
        <div className="d-settings__header">
          <span className="d-settings__title">Save Template</span>
          <button className="d-settings__close" onClick={onClose}>Esc</button>
        </div>
        <div style={{ padding: '16px 24px' }}>
          <label className="d-settings__label" style={{ display: 'block', marginBottom: 8 }}>
            Template Name
          </label>
          <input
            ref={inputRef}
            className="d-settings__input"
            style={{ width: '100%' }}
            value={name}
            onChange={(e) => setName(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && name.trim()) onSave(name.trim());
              if (e.key === 'Escape') onClose();
            }}
          />
          <button
            className="d-welcome__button"
            style={{ width: '100%', marginTop: 12 }}
            onClick={() => name.trim() && onSave(name.trim())}
          >
            Save Template
          </button>
        </div>
      </div>
    </div>
  );
}
