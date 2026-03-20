import { ipcMain, BrowserWindow, dialog, app, Notification } from 'electron';
import path from 'path';
import os from 'os';
import { PtyManager } from './pty-manager';
import { SessionStore } from './session-store';
import { IPC } from '../shared/types';
import { TmuxHelper } from './tmux';
import { TerminalMonitor } from './terminal-monitor';
import { ProjectDataStore } from './project-data-store';

export function registerIpc(ptyManager: PtyManager, store: SessionStore): void {
  const projectData = new ProjectDataStore(
    path.join(os.homedir(), '.config', 'dispatch', 'projects')
  );

  ipcMain.handle('project:loadTasks', async (_event, cwd: string) => projectData.loadTasks(cwd));
  ipcMain.handle('project:saveTasks', async (_event, cwd: string, tasks: unknown) => projectData.saveTasks(cwd, tasks as any));
  ipcMain.handle('project:loadNotes', async (_event, cwd: string) => projectData.loadNotes(cwd));
  ipcMain.handle('project:saveNotes', async (_event, cwd: string, notes: unknown) => projectData.saveNotes(cwd, notes as any));
  ipcMain.handle('project:loadVault', async (_event, cwd: string) => projectData.loadVault(cwd));
  ipcMain.handle('project:saveVault', async (_event, cwd: string, entries: unknown) => projectData.saveVault(cwd, entries as any));

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

  ipcMain.handle('settings:save', async (_event, settings) => {
    await store.saveSettings(settings);
  });

  const monitor = new TerminalMonitor(
    (terminalId, status) => {
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
    },
    (terminalId, url) => {
      const win = BrowserWindow.getAllWindows()[0];
      win?.webContents.send('browser:detected', terminalId, url);
    }
  );

  // Forward PTY events to renderer
  ptyManager.onData((id, data) => {
    const win = BrowserWindow.getAllWindows()[0];
    win?.webContents.send(IPC.PTY_DATA, id, data);
    monitor.onData(id, data);
  });

  ptyManager.onExit((id, code, signal) => {
    const win = BrowserWindow.getAllWindows()[0];
    win?.webContents.send(IPC.PTY_EXIT, id, code, signal);
    monitor.cleanup(id);
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

  ipcMain.handle('browser:clearPort', async (_event, port: string) => {
    monitor.clearPort(port);
  });

  ipcMain.handle('templates:load', async () => store.loadTemplates());
  ipcMain.handle('templates:save', async (_event, templates) => store.saveTemplates(templates));

  ipcMain.handle('resume:scan', async () => PtyManager.listDispatchSessions());

  ipcMain.handle('resume:restore', async (_event, sessionName: string) => {
    return ptyManager.attachSession(sessionName);
  });

  ipcMain.handle('resume:cleanup', async (_event, sessionNames: string[]) => {
    for (const name of sessionNames) {
      PtyManager.killSession(name);
    }
  });
}
