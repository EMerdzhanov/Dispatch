import React from 'react';
import { useStore } from '../store';
import { TasksPanel } from './TasksPanel';
import { NotesPanel } from './NotesPanel';
import { VaultPanel } from './VaultPanel';

export function ProjectPanel() {
  const activePanel = useStore((s) => s.activePanel);
  const setActivePanel = useStore((s) => s.setActivePanel);

  return (
    <div className="d-project-panel">
      <div className="d-panel-tabs">
        <button
          className={`d-panel-tab${activePanel === 'tasks' ? ' d-panel-tab--active' : ''}`}
          onClick={() => setActivePanel('tasks')}
        >
          ☑ Tasks
        </button>
        <button
          className={`d-panel-tab${activePanel === 'notes' ? ' d-panel-tab--active' : ''}`}
          onClick={() => setActivePanel('notes')}
        >
          📝 Notes
        </button>
        <button
          className={`d-panel-tab${activePanel === 'vault' ? ' d-panel-tab--active' : ''}`}
          onClick={() => setActivePanel('vault')}
        >
          🔑 Vault
        </button>
      </div>
      {activePanel === 'tasks' && <TasksPanel />}
      {activePanel === 'notes' && <NotesPanel />}
      {activePanel === 'vault' && <VaultPanel />}
    </div>
  );
}
