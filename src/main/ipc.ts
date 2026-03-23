import { ipcMain, BrowserWindow, dialog, app, Notification, nativeImage } from 'electron';
import path from 'path';
import os from 'os';
import { readdir } from 'fs/promises';
import { PtyManager } from './pty-manager';
import { SessionStore } from './session-store';
import { IPC } from '../shared/types';
import { TmuxHelper } from './tmux';
import { TerminalMonitor } from './terminal-monitor';
import { ProjectDataStore } from './project-data-store';
import { isValidTasks, isValidNotes, isValidVault } from './ipc-validators';

function getMainWindow(): BrowserWindow | null {
  const windows = BrowserWindow.getAllWindows();
  return windows.length > 0 ? windows[0] : null;
}

export function registerIpc(ptyManager: PtyManager, store: SessionStore): void {
  const projectData = new ProjectDataStore(
    path.join(os.homedir(), '.config', 'dispatch', 'projects')
  );

  ipcMain.handle('project:loadTasks', async (_event: any, cwd: string) => projectData.loadTasks(cwd));
  ipcMain.handle('project:saveTasks', async (_event: any, cwd: string, tasks: unknown) => {
    if (typeof cwd !== 'string' || !isValidTasks(tasks)) throw new Error('Invalid tasks data');
    return projectData.saveTasks(cwd, tasks);
  });
  ipcMain.handle('project:loadNotes', async (_event: any, cwd: string) => projectData.loadNotes(cwd));
  ipcMain.handle('project:saveNotes', async (_event: any, cwd: string, notes: unknown) => {
    if (typeof cwd !== 'string' || !isValidNotes(notes)) throw new Error('Invalid notes data');
    return projectData.saveNotes(cwd, notes);
  });
  ipcMain.handle('project:loadVault', async (_event: any, cwd: string) => projectData.loadVault(cwd));
  ipcMain.handle('project:saveVault', async (_event: any, cwd: string, entries: unknown) => {
    if (typeof cwd !== 'string' || !isValidVault(entries)) throw new Error('Invalid vault data');
    return projectData.saveVault(cwd, entries);
  });

  ipcMain.handle(IPC.PTY_SPAWN, async (_event: any, opts) => {
    return ptyManager.spawn(opts);
  });

  ipcMain.on(IPC.PTY_DATA, (_event: any, id: string, data: string) => {
    ptyManager.write(id, data);
  });

  ipcMain.on(IPC.PTY_RESIZE, (_event: any, id: string, cols: number, rows: number) => {
    if (typeof id !== 'string' || typeof cols !== 'number' || typeof rows !== 'number') return;
    if (cols < 1 || cols > 500 || rows < 1 || rows > 200) return;
    ptyManager.resize(id, cols, rows);
  });

  ipcMain.on(IPC.PTY_KILL, (_event: any, id: string) => {
    ptyManager.kill(id);
  });

  ipcMain.handle(IPC.STATE_LOAD, async () => {
    return {
      state: await store.loadState(),
      presets: await store.loadPresets(),
      settings: await store.loadSettings(),
    };
  });

  ipcMain.handle(IPC.STATE_SAVE, async (_event: any, state) => {
    await store.saveState(state);
  });

  ipcMain.handle('settings:save', async (_event: any, settings) => {
    await store.saveSettings(settings);
  });

  const monitor = new TerminalMonitor(
    (terminalId, status) => {
      const win = getMainWindow();
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
      const win = getMainWindow();
      win?.webContents.send('browser:detected', terminalId, url);
    }
  );

  // Forward PTY events to renderer
  ptyManager.onData((id, data) => {
    const win = getMainWindow();
    win?.webContents.send(IPC.PTY_DATA, id, data);
    monitor.onData(id, data);
  });

  ptyManager.onExit((id, code, signal) => {
    const win = getMainWindow();
    win?.webContents.send(IPC.PTY_EXIT, id, code, signal);
    monitor.cleanup(id);
  });

  ipcMain.handle('tmux:check', async () => {
    return TmuxHelper.isAvailable();
  });

  ipcMain.handle('dialog:openFolder', async () => {
    const win = getMainWindow();
    if (!win) return null;
    const result = await dialog.showOpenDialog(win, {
      properties: ['openDirectory'],
      title: 'Open Project Folder',
    });
    if (result.canceled || result.filePaths.length === 0) return null;
    return result.filePaths[0];
  });

  ipcMain.handle('browser:clearPort', async (_event: any, port: string) => {
    if (typeof port !== 'string' || !/^\d{1,5}$/.test(port)) return;
    monitor.clearPort(port);
  });

  ipcMain.handle('fs:readdir', async (_event: any, dirPath: string) => {
    if (typeof dirPath !== 'string' || dirPath.includes('\0')) return [];
    const resolved = path.resolve(dirPath);
    const home = os.homedir();
    if (resolved !== home && !resolved.startsWith(home + '/')) return [];
    try {
      const entries = await readdir(resolved, { withFileTypes: true });
      return entries
        .filter((e) => !e.name.startsWith('.'))
        .map((e) => ({ name: e.name, isDirectory: e.isDirectory() }))
        .sort((a, b) => {
          if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1;
          return a.name.localeCompare(b.name);
        });
    } catch { return []; }
  });

  ipcMain.handle('dialog:openScreenshot', async (_event: any, defaultPath?: string) => {
    const win = getMainWindow();
    if (!win) return null;
    const opts: any = {
      title: 'Select Screenshot',
      message: 'Choose an image to insert its path',
      properties: ['openFile'],
    };
    if (defaultPath) opts.defaultPath = defaultPath;
    const result = await dialog.showOpenDialog(win, opts);
    if (result.canceled || result.filePaths.length === 0) return null;
    return result.filePaths[0];
  });

  ipcMain.handle('dialog:selectScreenshotFolder', async () => {
    const win = getMainWindow();
    if (!win) return null;
    const result = await dialog.showOpenDialog(win, {
      title: 'Where are your screenshots saved?',
      message: 'Select your screenshots folder',
      properties: ['openDirectory'],
    });
    if (result.canceled || result.filePaths.length === 0) return null;
    return result.filePaths[0];
  });

  ipcMain.handle('dialog:openFile', async () => {
    const win = getMainWindow();
    if (!win) return null;
    const result = await dialog.showOpenDialog(win, {
      title: 'Select File',
      properties: ['openFile'],
    });
    if (result.canceled || result.filePaths.length === 0) return null;
    return result.filePaths[0];
  });

  ipcMain.handle('fs:thumbnail', async (_event: any, filePath: string) => {
    if (typeof filePath !== 'string' || filePath.includes('\0')) return null;
    const resolved = path.resolve(filePath);
    const home = os.homedir();
    if (resolved !== home && !resolved.startsWith(home + '/')) return null;
    try {
      const img = await nativeImage.createThumbnailFromPath(filePath, { width: 160, height: 100 });
      return img.toDataURL();
    } catch { return null; }
  });

  ipcMain.handle('templates:load', async () => store.loadTemplates());
  ipcMain.handle('templates:save', async (_event: any, templates: any) => store.saveTemplates(templates));

  ipcMain.handle('resume:scan', async () => PtyManager.listDispatchSessions());

  ipcMain.handle('resume:restore', async (_event: any, sessionName: string) => {
    if (typeof sessionName !== 'string' || !/^[a-zA-Z0-9_-]+$/.test(sessionName)) return null;
    return ptyManager.attachSession(sessionName);
  });

  ipcMain.handle('resume:cleanup', async (_event: any, sessionNames: string[]) => {
    if (!Array.isArray(sessionNames)) return;
    for (const name of sessionNames) {
      if (typeof name === 'string' && /^[a-zA-Z0-9_-]+$/.test(name)) {
        PtyManager.killSession(name);
      }
    }
  });

}
