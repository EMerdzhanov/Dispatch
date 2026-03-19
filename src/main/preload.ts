import { contextBridge } from 'electron';

contextBridge.exposeInMainWorld('dispatch', {
  pty: {
    spawn: async (_opts: unknown) => {},
    write: (_id: string, _data: string) => {},
    resize: (_id: string, _cols: number, _rows: number) => {},
    kill: (_id: string) => {},
    onData: (_cb: (id: string, data: string) => void) => {},
    onExit: (_cb: (id: string, code: number, signal: number) => void) => {},
  },
  state: {
    load: async () => ({}),
    save: async (_state: unknown) => {},
  },
  scanner: {
    onResults: (_cb: (results: unknown[]) => void) => {},
    attach: async (_pid: number) => {},
  },
});
