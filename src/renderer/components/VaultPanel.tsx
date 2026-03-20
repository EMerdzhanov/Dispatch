import React, { useState, useRef } from 'react';
import { useStore } from '../store';
import { useProjectApi } from '../hooks/usePty';
import type { VaultEntry } from '../../shared/types';

export function VaultPanel() {
  const vault = useStore((s) => s.projectVault);
  const setVault = useStore((s) => s.setProjectVault);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const projectApi = useProjectApi();
  const [showForm, setShowForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [formLabel, setFormLabel] = useState('');
  const [formValue, setFormValue] = useState('');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [contextId, setContextId] = useState<string | null>(null);
  const saveTimerRef = useRef<any>(null);

  const cwd = groups.find((g) => g.id === activeGroupId)?.cwd;

  const save = (updated: VaultEntry[]) => {
    setVault(updated);
    if (cwd && projectApi) {
      clearTimeout(saveTimerRef.current);
      saveTimerRef.current = setTimeout(() => projectApi.saveVault(cwd, updated), 500);
    }
  };

  const handleSave = () => {
    if (!formLabel.trim() || !formValue.trim()) return;
    if (editId) {
      save(vault.map((e) => e.id === editId ? { ...e, label: formLabel.trim(), value: formValue.trim() } : e));
    } else {
      save([...vault, { id: crypto.randomUUID(), label: formLabel.trim(), value: formValue.trim() }]);
    }
    setShowForm(false);
    setEditId(null);
    setFormLabel('');
    setFormValue('');
  };

  const startEdit = (entry: VaultEntry) => {
    setEditId(entry.id);
    setFormLabel(entry.label);
    setFormValue(entry.value);
    setShowForm(true);
    setContextId(null);
  };

  const deleteEntry = (id: string) => {
    save(vault.filter((e) => e.id !== id));
    setContextId(null);
  };

  const copyToClipboard = async (entry: VaultEntry) => {
    await navigator.clipboard.writeText(entry.value);
    setCopiedId(entry.id);
    setTimeout(() => setCopiedId(null), 1500);
  };

  const maskValue = (val: string): string => {
    if (val.length <= 3) return '••••';
    return val.slice(0, 3) + '••••';
  };

  return (
    <div className="d-panel-content">
      {showForm ? (
        <div className="d-vault-form">
          <input
            className="d-vault-form__input"
            placeholder="Label (e.g. API Key)"
            value={formLabel}
            onChange={(e) => setFormLabel(e.target.value)}
            autoFocus
          />
          <input
            className="d-vault-form__input"
            type="password"
            placeholder="Secret value"
            value={formValue}
            onChange={(e) => setFormValue(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') handleSave();
              if (e.key === 'Escape') { setShowForm(false); setEditId(null); }
            }}
          />
          <div style={{ display: 'flex', gap: 4, marginTop: 4 }}>
            <button className="d-welcome__button" style={{ flex: 1, padding: '4px 0', fontSize: 10 }} onClick={handleSave}>Save</button>
            <button className="d-context-menu__item" style={{ flex: 1, textAlign: 'center', fontSize: 10, padding: '4px 0', borderRadius: 'var(--radius-sm)' }}
              onClick={() => { setShowForm(false); setEditId(null); }}>Cancel</button>
          </div>
        </div>
      ) : (
        <button className="d-panel-add" onClick={() => { setShowForm(true); setEditId(null); setFormLabel(''); setFormValue(''); }}>
          + Add Secret
        </button>
      )}

      {vault.map((entry) => (
        <div key={entry.id} style={{ position: 'relative' }}>
          <div className="d-vault-item" onContextMenu={(e) => { e.preventDefault(); setContextId(entry.id); }}>
            <span className="d-vault-item__label">{entry.label}</span>
            <span className="d-vault-item__preview">{maskValue(entry.value)}</span>
            <button
              className={`d-vault-item__copy${copiedId === entry.id ? ' d-vault-item__copy--copied' : ''}`}
              onClick={() => copyToClipboard(entry)}
            >
              {copiedId === entry.id ? '✓' : 'Copy'}
            </button>
          </div>
          {contextId === entry.id && (
            <>
              <div className="d-context-overlay" onClick={() => setContextId(null)} />
              <div className="d-context-menu" style={{ top: 0, right: 0 }}>
                <button className="d-context-menu__item" onClick={() => startEdit(entry)}>Edit</button>
                <button className="d-context-menu__item d-context-menu__item--danger" onClick={() => deleteEntry(entry.id)}>Delete</button>
              </div>
            </>
          )}
        </div>
      ))}
    </div>
  );
}
