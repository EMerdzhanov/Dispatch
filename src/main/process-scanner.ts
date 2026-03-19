import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import os from 'os';

export interface ExternalTerminal {
  pid: number;
  command: string;
  cwd: string;
  emulator?: string;
}

const KNOWN_SHELLS = ['bash', 'zsh', 'fish', 'sh', 'dash'];

export class ProcessScanner {
  async scan(): Promise<ExternalTerminal[]> {
    if (process.platform === 'darwin') {
      return this.scanMac();
    } else if (process.platform === 'linux') {
      return this.scanLinux();
    }
    return [];
  }

  private scanMac(): ExternalTerminal[] {
    try {
      const uid = process.getuid?.() ?? 0;
      const output = execSync(`ps -eo pid,tty,comm -u ${uid}`, { encoding: 'utf-8', timeout: 5000 });
      const lines = output.trim().split('\n').slice(1);
      const results: ExternalTerminal[] = [];

      for (const line of lines) {
        const parts = line.trim().split(/\s+/);
        if (parts.length < 3) continue;
        const pid = parseInt(parts[0], 10);
        const tty = parts[1];
        const comm = parts.slice(2).join(' ');

        if (tty === '??' || tty === '-') continue;
        const basename = path.basename(comm);
        if (!KNOWN_SHELLS.includes(basename)) continue;

        let cwd = '';
        try {
          const lsofOut = execSync(`lsof -p ${pid} -d cwd -Fn 2>/dev/null`, { encoding: 'utf-8', timeout: 2000 });
          const cwdLine = lsofOut.split('\n').find((l) => l.startsWith('n'));
          if (cwdLine) cwd = cwdLine.slice(1);
        } catch {
          cwd = os.homedir();
        }

        results.push({ pid, command: basename, cwd });
      }

      return results;
    } catch {
      return [];
    }
  }

  private scanLinux(): ExternalTerminal[] {
    try {
      const uid = process.getuid?.() ?? 0;
      const procDirs = fs.readdirSync('/proc').filter((d) => /^\d+$/.test(d));
      const results: ExternalTerminal[] = [];

      for (const pidStr of procDirs) {
        try {
          const statusPath = `/proc/${pidStr}/status`;
          const status = fs.readFileSync(statusPath, 'utf-8');
          const uidLine = status.split('\n').find((l) => l.startsWith('Uid:'));
          if (!uidLine) continue;
          const processUid = parseInt(uidLine.split('\t')[1], 10);
          if (processUid !== uid) continue;

          const statPath = `/proc/${pidStr}/stat`;
          const stat = fs.readFileSync(statPath, 'utf-8');
          const statParts = stat.split(' ');
          const ttyNr = parseInt(statParts[6], 10);
          if (ttyNr === 0) continue;

          const comm = fs.readFileSync(`/proc/${pidStr}/comm`, 'utf-8').trim();
          if (!KNOWN_SHELLS.includes(comm)) continue;

          const cwd = fs.readlinkSync(`/proc/${pidStr}/cwd`);

          results.push({ pid: parseInt(pidStr, 10), command: comm, cwd });
        } catch {
          continue;
        }
      }

      return results;
    } catch {
      return [];
    }
  }
}
