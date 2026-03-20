import { ipcMain, BrowserWindow, dialog, app, Notification } from 'electron';
import { PtyManager } from './pty-manager';
import { SessionStore } from './session-store';
import { IPC } from '../shared/types';
import { TmuxHelper } from './tmux';
import { TerminalMonitor } from './terminal-monitor';

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

  const monitor = new TerminalMonitor((terminalId, status) => {
    const win = BrowserWindow.getAllWindows()[0];
    win?.webContents.send('monitor:status', terminalId, status);

    // Desktop notifications for success/error
    if (status === 'success' || status === 'error') {
      store.loadSettings().then((settings) => {
        if (!settings.notificationsEnabled) return;
        new Notification({
          title: `Dispatch: ${status === 'success' ? 'Task Complete' : 'Error Detected'}`,
          body: `Terminal activity detected`,
        }).show();
      });
    }
  });

  // Forward PTY events to renderer
  ptyManager.onData((id, data) => {
    const win = BrowserWindow.getAllWindows()[0];
    win?.webContents.send(IPC.PTY_DATA, id, data);
    monitor.onData(id, data);
  });

  ptyManager.onExit((id, code, signal) => {
    const win = BrowserWindow.getAllWindows()[0];
    win?.webContents.send(IPC.PTY_EXIT, id, code, signal);
  });

  ipcMain.handle('tmux:check', async () => {
    return TmuxHelper.isAvailable();
  });

  ipcMain.handle('dialog:openFolder', async () => {
    const win = BrowserWindow.getAllWindows()[0];
    const result = await dialog.showOpenDialog(win, {
      properties: ['openDirectory'],
      title: 'Open Project Folder',
    });
    if (result.canceled || result.filePaths.length === 0) return null;
    return result.filePaths[0];
  });

  ipcMain.handle('templates:load', async () => store.loadTemplates());
  ipcMain.handle('templates:save', async (_event, templates) => store.saveTemplates(templates));
}
