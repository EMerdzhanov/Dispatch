import { contextBridge, ipcRenderer } from 'electron';
import { IPC } from '../shared/types';

contextBridge.exposeInMainWorld('dispatch', {
  pty: {
    spawn: (opts: unknown) => ipcRenderer.invoke(IPC.PTY_SPAWN, opts),
    write: (id: string, data: string) => ipcRenderer.send(IPC.PTY_DATA, id, data),
    resize: (id: string, cols: number, rows: number) => ipcRenderer.send(IPC.PTY_RESIZE, id, cols, rows),
    kill: (id: string) => ipcRenderer.send(IPC.PTY_KILL, id),
    onData: (cb: (id: string, data: string) => void) => {
      const handler = (_event: any, id: string, data: string) => cb(id, data);
      ipcRenderer.on(IPC.PTY_DATA, handler);
      return () => ipcRenderer.removeListener(IPC.PTY_DATA, handler);
    },
    onExit: (cb: (id: string, code: number, signal: number) => void) => {
      const handler = (_event: any, id: string, code: number, signal: number) => cb(id, code, signal);
      ipcRenderer.on(IPC.PTY_EXIT, handler);
      return () => ipcRenderer.removeListener(IPC.PTY_EXIT, handler);
    },
  },
  app: {
    getHomedir: () => ipcRenderer.invoke('app:homedir'),
  },
  state: {
    load: () => ipcRenderer.invoke(IPC.STATE_LOAD),
    save: (state: unknown) => ipcRenderer.invoke(IPC.STATE_SAVE, state),
    saveSettings: (settings: unknown) => ipcRenderer.invoke('settings:save', settings),
  },
  dialog: {
    openFolder: () => ipcRenderer.invoke('dialog:openFolder'),
    openFile: () => ipcRenderer.invoke('dialog:openFile'),
    openScreenshot: (defaultPath?: string) => ipcRenderer.invoke('dialog:openScreenshot', defaultPath),
    selectScreenshotFolder: () => ipcRenderer.invoke('dialog:selectScreenshotFolder'),
  },
  tmux: {
    isAvailable: () => ipcRenderer.invoke('tmux:check'),
  },
  monitor: {
    onStatus: (cb: (id: string, status: string) => void) => {
      ipcRenderer.on('monitor:status', (_event: any, id: string, status: string) => cb(id, status));
    },
  },
  templates: {
    load: () => ipcRenderer.invoke('templates:load'),
    save: (templates: unknown) => ipcRenderer.invoke('templates:save', templates),
  },
  resume: {
    scan: () => ipcRenderer.invoke('resume:scan'),
    restore: (sessionName: string) => ipcRenderer.invoke('resume:restore', sessionName),
    cleanup: (sessionNames: string[]) => ipcRenderer.invoke('resume:cleanup', sessionNames),
  },
  project: {
    loadTasks: (cwd: string) => ipcRenderer.invoke('project:loadTasks', cwd),
    saveTasks: (cwd: string, tasks: unknown) => ipcRenderer.invoke('project:saveTasks', cwd, tasks),
    loadNotes: (cwd: string) => ipcRenderer.invoke('project:loadNotes', cwd),
    saveNotes: (cwd: string, notes: unknown) => ipcRenderer.invoke('project:saveNotes', cwd, notes),
    loadVault: (cwd: string) => ipcRenderer.invoke('project:loadVault', cwd),
    saveVault: (cwd: string, entries: unknown) => ipcRenderer.invoke('project:saveVault', cwd, entries),
  },
  fs: {
    readdir: (dirPath: string) => ipcRenderer.invoke('fs:readdir', dirPath),
    thumbnail: (filePath: string) => ipcRenderer.invoke('fs:thumbnail', filePath),
  },
  browser: {
    onDetected: (cb: (terminalId: string, url: string) => void) => {
      ipcRenderer.on('browser:detected', (_event: any, terminalId: string, url: string) => cb(terminalId, url));
    },
    clearPort: (port: string) => ipcRenderer.invoke('browser:clearPort', port),
  },
});
