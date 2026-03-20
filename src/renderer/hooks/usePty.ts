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
      dialog: {
        openFolder: () => Promise<string | null>;
      };
      tmux: {
        isAvailable: () => Promise<boolean>;
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

export function useDialogApi() {
  return window.dispatch.dialog;
}

export function useAppApi() {
  return window.dispatch.app;
}

export function useProjectApi() {
  return (window as any).dispatch?.project;
}
