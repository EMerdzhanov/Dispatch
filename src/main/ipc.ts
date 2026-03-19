import { ipcMain, BrowserWindow } from 'electron';
import { PtyManager } from './pty-manager';
import { SessionStore } from './session-store';
import { IPC } from '../shared/types';

export function registerIpc(ptyManager: PtyManager, store: SessionStore): void {
  ipcMain.handle(IPC.PTY_SPAWN, async (_event, opts) => {
    return ptyManager.spawn(opts);
  });

  ipcMain.on(IPC.PTY_DATA, (_event, id: string, data: string) => {
    ptyManager.write(id, data);
  });

  ipcMain.on(IPC.PTY_RESIZE, (_event, id: string, cols: number, rows: number) => {
    ptyManager.resize(id, cols, rows);
  });

  ipcMain.on(IPC.PTY_KILL, (_event, id: string) => {
    ptyManager.kill(id);
  });

  ipcMain.handle(IPC.STATE_LOAD, async () => {
    return {
      state: await store.loadState(),
      presets: await store.loadPresets(),
      settings: await store.loadSettings(),
    };
  });

  ipcMain.handle(IPC.STATE_SAVE, async (_event, state) => {
    await store.saveState(state);
  });

  // Forward PTY events to renderer
  ptyManager.onData((id, data) => {
    const win = BrowserWindow.getAllWindows()[0];
    win?.webContents.send(IPC.PTY_DATA, id, data);
  });

  ptyManager.onExit((id, code, signal) => {
    const win = BrowserWindow.getAllWindows()[0];
    win?.webContents.send(IPC.PTY_EXIT, id, code, signal);
  });
}
