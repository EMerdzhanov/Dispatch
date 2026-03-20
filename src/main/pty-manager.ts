import * as pty from 'node-pty';
import os from 'os';
import fs from 'fs';
import { execSync } from 'child_process';
import { randomUUID } from 'crypto';
import type { SpawnOptions } from '../shared/types';

type DataCallback = (id: string, data: string) => void;
type ExitCallback = (id: string, exitCode: number, signal: number) => void;

function isTmuxAvailable(): boolean {
  try {
    execSync('which tmux', { stdio: 'ignore', timeout: 2000 });
    return true;
  } catch {
    return false;
  }
}

function tmuxSessionExists(sessionName: string): boolean {
  try {
    execSync(`tmux has-session -t "${sessionName}"`, { stdio: 'ignore', timeout: 2000 });
    return true;
  } catch {
    return false;
  }
}

export class PtyManager {
  private terminals = new Map<string, pty.IPty>();
  private dataCallbacks: DataCallback[] = [];
  private exitCallbacks: ExitCallback[] = [];
  private tmuxAvailable = isTmuxAvailable();
  private sessionCounter = new Map<string, number>();

  private getSessionName(cwd: string): string {
    const folderName = cwd.split('/').pop() || 'unknown';
    const safe = folderName.replace(/[^a-zA-Z0-9_-]/g, '-');
    const count = this.sessionCounter.get(safe) || 0;
    this.sessionCounter.set(safe, count + 1);
    return `dispatch-${safe}-${count}`;
  }

  spawn(opts: SpawnOptions): string {
    const id = randomUUID();
    let cwd = opts.cwd;

    // Validate CWD exists, fallback to home
    if (!fs.existsSync(cwd)) {
      cwd = os.homedir();
    }

    // Build environment — inherit everything from the system
    const env: Record<string, string> = {
      ...process.env as Record<string, string>,
      ...opts.env,
      TERM: 'xterm-256color',
      COLORTERM: 'truecolor',
      LANG: process.env.LANG || 'en_US.UTF-8',
    };

    let shellPath: string;
    let shellArgs: string[];
    let commandToType: string | undefined;

    if (this.tmuxAvailable && !opts.noTmux) {
      // Use tmux for session persistence
      const sessionName = this.getSessionName(cwd);

      if (tmuxSessionExists(sessionName)) {
        // Re-attach to existing session
        shellPath = 'tmux';
        shellArgs = ['attach-session', '-t', sessionName];
      } else {
        // Create a new tmux session
        shellPath = 'tmux';
        shellArgs = ['new-session', '-s', sessionName, '-c', cwd];
      }

      // If a command needs to be typed inside the tmux shell (e.g. claude)
      if (opts.command && opts.command !== '$SHELL') {
        commandToType = opts.command;
      }
    } else {
      // Fallback: plain shell without tmux
      const userShell = process.env.SHELL || '/bin/zsh';
      shellPath = userShell;
      shellArgs = ['--login'];

      if (opts.command && opts.command !== '$SHELL') {
        commandToType = opts.command;
      }
    }

    let term: pty.IPty;
    try {
      term = pty.spawn(shellPath, shellArgs, {
        name: 'xterm-256color',
        cols: 80,
        rows: 24,
        cwd,
        env,
      });
    } catch {
      // Fallback to plain shell
      const userShell = process.env.SHELL || '/bin/zsh';
      term = pty.spawn(userShell, ['--login'], {
        name: 'xterm-256color',
        cols: 80,
        rows: 24,
        cwd,
        env,
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

    // If there's a command to type, send it after a short delay
    // so the shell (and tmux shell) has time to initialize
    if (commandToType) {
      const delay = this.tmuxAvailable ? 600 : 300;
      setTimeout(() => {
        term.write(commandToType + '\r');
      }, delay);
    }

    return id;
  }

  /** Get all PIDs of terminals spawned by Dispatch */
  getOwnPids(): Set<number> {
    const pids = new Set<number>();
    for (const term of this.terminals.values()) {
      pids.add(term.pid);
    }
    return pids;
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

  attachSession(sessionName: string): string {
    const id = randomUUID();
    const env = {
      ...process.env as Record<string, string>,
      TERM: 'xterm-256color',
      COLORTERM: 'truecolor',
    };

    const term = pty.spawn('tmux', ['attach-session', '-t', sessionName], {
      name: 'xterm-256color',
      cols: 80,
      rows: 24,
      cwd: process.env.HOME || '/',
      env,
    });

    this.terminals.set(id, term);
    term.onData((data) => { for (const cb of this.dataCallbacks) cb(id, data); });
    term.onExit(({ exitCode, signal }) => {
      this.terminals.delete(id);
      for (const cb of this.exitCallbacks) cb(id, exitCode ?? 0, signal ?? 0);
    });

    return id;
  }

  static listDispatchSessions(): { name: string; cwd: string }[] {
    try {
      const output = execSync(
        'tmux list-sessions -F "#{session_name}" 2>/dev/null',
        { encoding: 'utf-8', timeout: 3000 }
      ).trim();
      const sessions = output.split('\n').filter((s) => s.startsWith('dispatch-'));

      return sessions.map((name) => {
        let cwd = '';
        try {
          cwd = execSync(
            `tmux display-message -t "${name}" -p "#{pane_current_path}" 2>/dev/null`,
            { encoding: 'utf-8', timeout: 2000 }
          ).trim();
        } catch { cwd = ''; }
        return { name, cwd };
      });
    } catch { return []; }
  }

  static killSession(name: string): void {
    try {
      execSync(`tmux kill-session -t "${name}" 2>/dev/null`, { timeout: 2000 });
    } catch {}
  }
}
