import React from 'react';
import { useStore } from '../store';

interface ResumeModalProps {
  onRestore: () => void;
  onFresh: () => void;
}

export function ResumeModal({ onRestore, onFresh }: ResumeModalProps) {
  const sessions = useStore((s) => s.resumeSessions);
  const toggleSession = useStore((s) => s.toggleResumeSession);

  if (!sessions || sessions.length === 0) return null;

  const grouped = new Map<string, typeof sessions>();
  for (const s of sessions) {
    const key = s.folderName;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key)!.push(s);
  }

  const selectedCount = sessions.filter((s) => s.selected).length;

  return (
    <div className="d-overlay d-overlay--center">
      <div className="d-overlay__backdrop" />
      <div className="d-overlay__panel" style={{ width: 500 }} onClick={(e) => e.stopPropagation()}>
        <div className="d-settings__header">
          <span className="d-settings__title">Restore Previous Sessions</span>
        </div>
        <div style={{ padding: '16px 24px', maxHeight: '60vh', overflowY: 'auto' }}>
          <p style={{ fontSize: 12, color: 'var(--text-muted)', marginBottom: 16 }}>
            Found {sessions.length} session{sessions.length !== 1 ? 's' : ''} from your last run:
          </p>
          {Array.from(grouped.entries()).map(([folder, items]) => (
            <div key={folder} style={{ marginBottom: 12 }}>
              <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 4 }}>
                {folder} ({items.length} terminal{items.length !== 1 ? 's' : ''})
              </div>
              {items.map((s) => (
                <label key={s.sessionName} className="d-entry"
                  style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', marginBottom: 2 }}>
                  <input
                    type="checkbox"
                    checked={s.selected}
                    onChange={() => toggleSession(s.sessionName)}
                    style={{ flexShrink: 0 }}
                  />
                  <div style={{ overflow: 'hidden' }}>
                    <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>{s.sessionName}</div>
                    <div style={{ fontSize: 9, color: 'var(--text-dim)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.cwd}</div>
                  </div>
                </label>
              ))}
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 8, padding: '16px 24px', borderTop: '1px solid var(--border-default)' }}>
          <button className="d-welcome__button" style={{ flex: 1 }} onClick={onRestore}
            disabled={selectedCount === 0}>
            Restore {selectedCount > 0 ? `(${selectedCount})` : ''}
          </button>
          <button className="d-context-menu__item" style={{ flex: 1, textAlign: 'center', padding: '10px 0', borderRadius: 'var(--radius-lg)' }} onClick={onFresh}>
            Start Fresh
          </button>
        </div>
      </div>
    </div>
  );
}
