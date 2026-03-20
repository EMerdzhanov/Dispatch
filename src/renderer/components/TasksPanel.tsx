import React, { useState } from 'react';
import { useStore } from '../store';
import { useProjectApi } from '../hooks/usePty';
import type { Task } from '../../shared/types';

let saveTimer: any = null;

export function TasksPanel() {
  const tasks = useStore((s) => s.projectTasks);
  const setTasks = useStore((s) => s.setProjectTasks);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const [input, setInput] = useState('');
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const projectApi = useProjectApi();

  const cwd = groups.find((g) => g.id === activeGroupId)?.cwd;

  const save = (updated: Task[]) => {
    setTasks(updated);
    if (cwd && projectApi) {
      clearTimeout(saveTimer);
      saveTimer = setTimeout(() => projectApi.saveTasks(cwd, updated), 500);
    }
  };

  const addTask = () => {
    if (!input.trim()) return;
    const task: Task = { id: crypto.randomUUID(), title: input.trim(), description: '', done: false };
    save([task, ...tasks]);
    setInput('');
  };

  const toggleDone = (id: string) => {
    save(tasks.map((t) => t.id === id ? { ...t, done: !t.done } : t));
  };

  const deleteTask = (id: string) => {
    save(tasks.filter((t) => t.id !== id));
    if (expandedId === id) setExpandedId(null);
  };

  const updateDesc = (id: string, description: string) => {
    save(tasks.map((t) => t.id === id ? { ...t, description } : t));
  };

  const sorted = [...tasks].sort((a, b) => Number(a.done) - Number(b.done));

  return (
    <div className="d-panel-content">
      <input
        className="d-task-input"
        placeholder="Add task..."
        value={input}
        onChange={(e) => setInput(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter') addTask(); }}
      />
      {sorted.map((task) => (
        <div key={task.id}>
          <div className={`d-task-item${task.done ? ' d-task-item--done' : ''}`}>
            <input
              type="checkbox"
              className="d-task-item__checkbox"
              checked={task.done}
              onChange={() => toggleDone(task.id)}
            />
            <span
              className="d-task-item__title"
              onClick={() => setExpandedId(expandedId === task.id ? null : task.id)}
            >
              {task.title}
            </span>
            <button className="d-task-item__delete" onClick={() => deleteTask(task.id)}>✕</button>
          </div>
          {expandedId === task.id && (
            <textarea
              className="d-task-item__desc"
              placeholder="Add description..."
              value={task.description}
              onChange={(e) => updateDesc(task.id, e.target.value)}
            />
          )}
        </div>
      ))}
    </div>
  );
}
