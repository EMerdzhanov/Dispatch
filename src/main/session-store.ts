import fs from 'fs/promises';
import fsSync from 'fs';
import path from 'path';
import { type AppState, type Preset, type Settings, type Template, DEFAULT_PRESETS, DEFAULT_SETTINGS } from '../shared/types';

const DEFAULT_STATE: AppState = {
  groups: [],
  activeGroupId: null,
  activeTerminalId: null,
  windowBounds: { x: 0, y: 0, width: 1200, height: 800 },
  sidebarWidth: 220,
};

export class SessionStore {
  private dir: string;

  constructor(configDir: string) {
    this.dir = configDir;
    if (!fsSync.existsSync(this.dir)) {
      fsSync.mkdirSync(this.dir, { recursive: true });
    }
  }

  private filePath(name: string): string {
    return path.join(this.dir, name);
  }

  private async readJson<T>(name: string, fallback: T): Promise<T> {
    try {
      const raw = await fs.readFile(this.filePath(name), 'utf-8');
      return JSON.parse(raw) as T;
    } catch {
      return fallback;
    }
  }

  private async writeJson(name: string, data: unknown): Promise<void> {
    await fs.writeFile(this.filePath(name), JSON.stringify(data, null, 2), 'utf-8');
  }

  async loadState(): Promise<AppState> {
    return this.readJson('state.json', DEFAULT_STATE);
  }

  async saveState(state: AppState): Promise<void> {
    const statePath = this.filePath('state.json');
    try {
      await fs.access(statePath);
      // File exists — backup before overwriting. If backup fails, abort save.
      await fs.copyFile(statePath, this.filePath('state.json.bak'));
    } catch (err: any) {
      // ENOENT means no existing file to backup — safe to proceed
      if (err?.code !== 'ENOENT') throw err;
    }
    await this.writeJson('state.json', state);
  }

  async loadPresets(): Promise<Preset[]> {
    return this.readJson('presets.json', DEFAULT_PRESETS);
  }

  async savePresets(presets: Preset[]): Promise<void> {
    await this.writeJson('presets.json', presets);
  }

  async loadSettings(): Promise<Settings> {
    const saved = await this.readJson<Partial<Settings>>('settings.json', {});
    return { ...DEFAULT_SETTINGS, ...saved };
  }

  async saveSettings(settings: Settings): Promise<void> {
    await this.writeJson('settings.json', settings);
  }

  async loadTemplates(): Promise<Template[]> {
    return this.readJson('templates.json', []);
  }

  async saveTemplates(templates: Template[]): Promise<void> {
    await this.writeJson('templates.json', templates);
  }
}
