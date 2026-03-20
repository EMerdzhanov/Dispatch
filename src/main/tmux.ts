import { execFileSync } from 'child_process';

export interface TmuxSession {
  name: string;
  windows: number;
  attached: boolean;
}

export class TmuxHelper {
  static isAvailable(): boolean {
    try {
      execFileSync('which', ['tmux'], { stdio: 'ignore', timeout: 2000 });
      return true;
    } catch { return false; }
  }

  static listSessions(): TmuxSession[] {
    if (!this.isAvailable()) return [];
    try {
      const output = execFileSync('tmux', ['list-sessions', '-F', '#{session_name}:#{session_windows}:#{session_attached}'],
        { encoding: 'utf-8', timeout: 3000 });
      return output.trim().split('\n').filter(Boolean).map((line) => {
        const [name, windows, attached] = line.split(':');
        return { name, windows: parseInt(windows, 10), attached: attached === '1' };
      });
    } catch { return []; }
  }

  static getAttachCommand(sessionName: string): string {
    return `tmux attach-session -t ${sessionName}`;
  }

  static findSessionForPid(pid: number): string | null {
    if (!this.isAvailable()) return null;
    try {
      const output = execFileSync('tmux', ['list-panes', '-a', '-F', '#{pane_pid}:#{session_name}'],
        { encoding: 'utf-8', timeout: 3000 });
      for (const line of output.trim().split('\n')) {
        const [panePid, sessionName] = line.split(':');
        if (parseInt(panePid, 10) === pid) return sessionName;
      }
      return null;
    } catch { return null; }
  }
}
