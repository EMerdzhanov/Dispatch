import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { SessionStore } from '../../src/main/session-store';

describe('SessionStore', () => {
  let tmpDir: string;
  let store: SessionStore;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dispatch-test-'));
    store = new SessionStore(tmpDir);
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  describe('state', () => {
    it('returns default state when state.json does not exist', async () => {
      const state = await store.loadState();
      expect(state.groups).toEqual([]);
      expect(state.activeGroupId).toBeNull();
    });

    it('saves and loads state', async () => {
      const state = { groups: [], activeGroupId: 'g1', activeTerminalId: null, windowBounds: { x: 0, y: 0, width: 1200, height: 800 }, sidebarWidth: 220 };
      await store.saveState(state);
      const loaded = await store.loadState();
      expect(loaded.activeGroupId).toBe('g1');
    });

    it('recovers from corrupted state.json', async () => {
      fs.writeFileSync(path.join(tmpDir, 'state.json'), '{invalid json!!}');
      const state = await store.loadState();
      expect(state.groups).toEqual([]);
    });

    it('creates backup before overwriting state', async () => {
      const state1 = { groups: [], activeGroupId: 'g1', activeTerminalId: null, windowBounds: { x: 0, y: 0, width: 1200, height: 800 }, sidebarWidth: 220 };
      await store.saveState(state1);
      const state2 = { ...state1, activeGroupId: 'g2' };
      await store.saveState(state2);
      const backup = JSON.parse(fs.readFileSync(path.join(tmpDir, 'state.json.bak'), 'utf-8'));
      expect(backup.activeGroupId).toBe('g1');
    });

    it('aborts save if backup copy fails on existing file', async () => {
      const state1 = { groups: [], activeGroupId: 'g1', activeTerminalId: null, windowBounds: { x: 0, y: 0, width: 1200, height: 800 }, sidebarWidth: 220 };
      await store.saveState(state1);

      // Make the backup target unwritable to force copyFile failure
      const bakPath = path.join(tmpDir, 'state.json.bak');
      fs.writeFileSync(bakPath, 'original backup');
      fs.chmodSync(bakPath, 0o000);

      const state2 = { ...state1, sidebarWidth: 999 };
      await expect(store.saveState(state2)).rejects.toThrow();

      // Restore permissions for cleanup
      fs.chmodSync(bakPath, 0o644);

      // Original state.json should be unchanged
      const loaded = await store.loadState();
      expect(loaded.sidebarWidth).toBe(220);
    });
  });

  describe('presets', () => {
    it('returns default presets when presets.json does not exist', async () => {
      const presets = await store.loadPresets();
      expect(presets).toHaveLength(4);
      expect(presets[0].name).toBe('Claude Code');
    });

    it('saves and loads custom presets', async () => {
      const presets = [{ name: 'Test', command: 'echo hi', color: '#fff', icon: 'test' }];
      await store.savePresets(presets);
      const loaded = await store.loadPresets();
      expect(loaded).toHaveLength(1);
      expect(loaded[0].name).toBe('Test');
    });
  });

  describe('settings', () => {
    it('returns default settings when settings.json does not exist', async () => {
      const settings = await store.loadSettings();
      expect(settings.fontSize).toBe(13);
      expect(settings.scanInterval).toBe(10000);
    });
  });
});
