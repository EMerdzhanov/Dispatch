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
  },
  scanner: {
    onResults: (cb: (results: unknown[]) => void) => {
      ipcRenderer.on(IPC.SCANNER_RESULTS, (_event, results) => cb(results));
    },
    attach: (pid: number) => ipcRenderer.invoke(IPC.SCANNER_ATTACH, pid),
  },
  tmux: {
    isAvailable: () => ipcRenderer.invoke('tmux:check'),
  },
});
