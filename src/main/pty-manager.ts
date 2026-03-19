import * as pty from 'node-pty';
import os from 'os';
import fs from 'fs';
import { randomUUID } from 'crypto';
import type { SpawnOptions } from '../shared/types';

type DataCallback = (id: string, data: string) => void;
type ExitCallback = (id: string, exitCode: number, signal: number) => void;

export class PtyManager {
  private terminals = new Map<string, pty.IPty>();
  private dataCallbacks: DataCallback[] = [];
  private exitCallbacks: ExitCallback[] = [];

  spawn(opts: SpawnOptions): string {
    const id = randomUUID();
    let shell = opts.shell || process.env.SHELL || '/bin/sh';
    let cwd = opts.cwd;

    // Validate CWD exists, fallback to home
    if (!fs.existsSync(cwd)) {
      cwd = os.homedir();
    }

    let term: pty.IPty;
    try {
      term = pty.spawn(shell, [], {
        name: 'xterm-256color',
        cols: 80,
        rows: 24,
        cwd,
        env: { ...process.env, ...opts.env } as Record<string, string>,
      });
    } catch {
      // Fallback to /bin/sh if the requested shell fails
      shell = '/bin/sh';
      term = pty.spawn(shell, [], {
        name: 'xterm-256color',
        cols: 80,
        rows: 24,
        cwd,
        env: { ...process.env, ...opts.env } as Record<string, string>,
      });
    }

    this.terminals.set(id, term);

    term.onData((data) => {
      for (const cb of this.dataCallbacks) cb(id, data);
    });

    term.onExit(({ exitCode, signal }) => {
      this.terminals.delete(id);
      for (const cb of this.exitCallbacks) cb(id, exitCode ?? 0, signal ?? 0);
    });

    // If a command was specified, send it
    if (opts.command) {
      term.write(opts.command + '\r');
    }

    return id;
  }

  write(id: string, data: string): void {
    this.terminals.get(id)?.write(data);
  }

  resize(id: string, cols: number, rows: number): void {
    this.terminals.get(id)?.resize(cols, rows);
  }

  kill(id: string): void {
    const term = this.terminals.get(id);
    if (term) {
      term.kill();
      this.terminals.delete(id);
    }
  }

  killAll(): void {
    for (const [id] of this.terminals) {
      this.kill(id);
    }
  }

  get(id: string): pty.IPty | undefined {
    return this.terminals.get(id);
  }

  onData(cb: DataCallback): void {
    this.dataCallbacks.push(cb);
  }

  onExit(cb: ExitCallback): void {
    this.exitCallbacks.push(cb);
  }
}
