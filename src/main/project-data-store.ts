import { createHash } from 'crypto';
import fs from 'fs/promises';
import fsSync from 'fs';
import path from 'path';
import type { Task, Note, VaultEntry } from '../shared/types';

export class ProjectDataStore {
  private baseDir: string;

  constructor(baseDir: string) {
    this.baseDir = baseDir;
  }

  getProjectDir(cwd: string): string {
    const normalized = cwd.replace(/\\/g, '/');
    const hash = createHash('sha256').update(normalized).digest('hex').slice(0, 12);
    return path.join(this.baseDir, hash);
  }

  private async readJson<T>(cwd: string, filename: string, fallback: T): Promise<T> {
    try {
      const filePath = path.join(this.getProjectDir(cwd), filename);
      const raw = await fs.readFile(filePath, 'utf-8');
      return JSON.parse(raw) as T;
    } catch {
      return fallback;
    }
  }

  private async writeJson(cwd: string, filename: string, data: unknown): Promise<void> {
    const dir = this.getProjectDir(cwd);
    if (!fsSync.existsSync(dir)) {
      await fs.mkdir(dir, { recursive: true });
    }
    await fs.writeFile(path.join(dir, filename), JSON.stringify(data, null, 2), 'utf-8');
  }

  async loadTasks(cwd: string): Promise<Task[]> { return this.readJson(cwd, 'tasks.json', []); }
  async saveTasks(cwd: string, tasks: Task[]): Promise<void> { await this.writeJson(cwd, 'tasks.json', tasks); }
  async loadNotes(cwd: string): Promise<Note[]> { return this.readJson(cwd, 'notes.json', []); }
  async saveNotes(cwd: string, notes: Note[]): Promise<void> { await this.writeJson(cwd, 'notes.json', notes); }
  async loadVault(cwd: string): Promise<VaultEntry[]> { return this.readJson(cwd, 'vault.json', []); }
  async saveVault(cwd: string, entries: VaultEntry[]): Promise<void> { await this.writeJson(cwd, 'vault.json', entries); }
}
