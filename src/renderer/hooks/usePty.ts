declare global {
  interface Window {
    dispatch: {
      pty: {
        spawn: (opts: unknown) => Promise<string>;
        write: (id: string, data: string) => void;
        resize: (id: string, cols: number, rows: number) => void;
        kill: (id: string) => void;
        onData: (cb: (id: string, data: string) => void) => () => void;
        onExit: (cb: (id: string, code: number, signal: number) => void) => () => void;
      };
      app: {
        getHomedir: () => Promise<string>;
      };
      state: {
        load: () => Promise<unknown>;
        save: (state: unknown) => Promise<void>;
      };
      scanner: {
        onResults: (cb: (results: unknown[]) => void) => void;
        attach: (pid: number) => Promise<void>;
      };
    };
  }
}

export function usePty() {
  return window.dispatch.pty;
}

export function useStateApi() {
  return window.dispatch.state;
}

export function useScannerApi() {
  return window.dispatch.scanner;
}

export function useAppApi() {
  return window.dispatch.app;
}
