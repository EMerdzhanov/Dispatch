import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { ProjectDataStore } from '../../src/main/project-data-store';

describe('ProjectDataStore', () => {
  let tmpDir: string;
  let store: ProjectDataStore;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dispatch-pds-'));
    store = new ProjectDataStore(tmpDir);
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('generates deterministic project dir from CWD', () => {
    const dir1 = store.getProjectDir('/Users/test/project');
    const dir2 = store.getProjectDir('/Users/test/project');
    expect(dir1).toBe(dir2);
  });

  it('generates different dirs for different CWDs', () => {
    const dir1 = store.getProjectDir('/Users/test/project1');
    const dir2 = store.getProjectDir('/Users/test/project2');
    expect(dir1).not.toBe(dir2);
  });

  describe('tasks', () => {
    it('returns empty array when no tasks exist', async () => {
      expect(await store.loadTasks('/test/project')).toEqual([]);
    });
    it('saves and loads tasks', async () => {
      const tasks = [{ id: '1', title: 'Test', description: '', done: false }];
      await store.saveTasks('/test/project', tasks);
      expect(await store.loadTasks('/test/project')).toEqual(tasks);
    });
  });

  describe('notes', () => {
    it('returns empty array when no notes exist', async () => {
      expect(await store.loadNotes('/test/project')).toEqual([]);
    });
    it('saves and loads notes', async () => {
      const notes = [{ id: '1', title: 'Note', body: 'content', updatedAt: 1000 }];
      await store.saveNotes('/test/project', notes);
      expect(await store.loadNotes('/test/project')).toEqual(notes);
    });
  });

  describe('vault', () => {
    it('returns empty array when no vault exists', async () => {
      expect(await store.loadVault('/test/project')).toEqual([]);
    });
    it('saves and loads vault entries', async () => {
      const entries = [{ id: '1', label: 'Key', value: 'sk-123' }];
      await store.saveVault('/test/project', entries);
      expect(await store.loadVault('/test/project')).toEqual(entries);
    });
  });

  it('recovers from corrupted JSON', async () => {
    const dir = store.getProjectDir('/test/corrupt');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'tasks.json'), '{broken!!');
    expect(await store.loadTasks('/test/corrupt')).toEqual([]);
  });
});
