import React, { useState } from 'react';
import { useStore } from '../store';
import { useProjectApi } from '../hooks/usePty';
import type { Note } from '../../shared/types';

let saveTimer: any = null;

export function NotesPanel() {
  const notes = useStore((s) => s.projectNotes);
  const setNotes = useStore((s) => s.setProjectNotes);
  const editingNoteId = useStore((s) => s.editingNoteId);
  const setEditingNoteId = useStore((s) => s.setEditingNoteId);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const projectApi = useProjectApi();
  const [contextId, setContextId] = useState<string | null>(null);

  const cwd = groups.find((g) => g.id === activeGroupId)?.cwd;

  const save = (updated: Note[]) => {
    setNotes(updated);
    if (cwd && projectApi) {
      clearTimeout(saveTimer);
      saveTimer = setTimeout(() => projectApi.saveNotes(cwd, updated), 500);
    }
  };

  const addNote = () => {
    const note: Note = { id: crypto.randomUUID(), title: 'Untitled Note', body: '', updatedAt: Date.now() };
    save([note, ...notes]);
    setEditingNoteId(note.id);
  };

  const updateNote = (id: string, updates: Partial<Note>) => {
    save(notes.map((n) => n.id === id ? { ...n, ...updates, updatedAt: Date.now() } : n));
  };

  const deleteNote = (id: string) => {
    save(notes.filter((n) => n.id !== id));
    setContextId(null);
    if (editingNoteId === id) setEditingNoteId(null);
  };

  const sorted = [...notes].sort((a, b) => b.updatedAt - a.updatedAt);

  // Edit view
  const editingNote = editingNoteId ? notes.find((n) => n.id === editingNoteId) : null;
  if (editingNote) {
    return (
      <div className="d-panel-content" style={{ display: 'flex', flexDirection: 'column' }}>
        <div className="d-note-edit__header">
          <button className="d-note-edit__back" onClick={() => setEditingNoteId(null)}>←</button>
          <input
            className="d-note-edit__title"
            value={editingNote.title}
            onChange={(e) => updateNote(editingNote.id, { title: e.target.value })}
          />
        </div>
        <textarea
          className="d-note-edit__body"
          style={{ flex: 1 }}
          value={editingNote.body}
          onChange={(e) => updateNote(editingNote.id, { body: e.target.value })}
          placeholder="Write your note..."
          autoFocus
        />
      </div>
    );
  }

  // List view
  return (
    <div className="d-panel-content">
      <button className="d-panel-add" onClick={addNote}>+ Add Note</button>
      {sorted.map((note) => (
        <div key={note.id} style={{ position: 'relative' }}>
          <div
            className="d-note-item"
            onClick={() => setEditingNoteId(note.id)}
            onContextMenu={(e) => { e.preventDefault(); setContextId(note.id); }}
          >
            <div className="d-note-item__title">{note.title}</div>
            <div className="d-note-item__date">{new Date(note.updatedAt).toLocaleDateString()}</div>
          </div>
          {contextId === note.id && (
            <>
              <div className="d-context-overlay" onClick={() => setContextId(null)} />
              <div className="d-context-menu" style={{ top: 0, right: 0 }}>
                <button className="d-context-menu__item d-context-menu__item--danger" onClick={() => deleteNote(note.id)}>
                  Delete Note
                </button>
              </div>
            </>
          )}
        </div>
      ))}
    </div>
  );
}
