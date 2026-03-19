import { describe, it, expect, afterEach } from 'vitest';
import { PtyManager } from '../../src/main/pty-manager';
import os from 'os';

describe('PtyManager', () => {
  let manager: PtyManager;

  afterEach(() => {
    manager?.killAll();
  });

  it('spawns a terminal and returns an id', () => {
    manager = new PtyManager();
    const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh', noTmux: true });
    expect(id).toBeTruthy();
    expect(manager.get(id)).toBeDefined();
  });

  it('receives data from spawned terminal', async () => {
    manager = new PtyManager();
    const received: string[] = [];
    manager.onData((id, data) => received.push(data));
    const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh', noTmux: true });
    manager.write(id, 'echo hello\r');
    await new Promise((r) => setTimeout(r, 500));
    expect(received.length).toBeGreaterThan(0);
  });

  it('fires onExit when process ends', async () => {
    manager = new PtyManager();
    let exitId = '';
    let exitCode = -1;
    manager.onExit((id, code) => { exitId = id; exitCode = code; });
    const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh', noTmux: true });
    manager.write(id, 'exit 0\r');
    await new Promise((r) => setTimeout(r, 2000));
    expect(exitId).toBe(id);
    expect(exitCode).toBe(0);
  });

  it('kill removes the terminal', () => {
    manager = new PtyManager();
    const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh', noTmux: true });
    manager.kill(id);
    expect(manager.get(id)).toBeUndefined();
  });

  it('resize does not throw for valid terminal', () => {
    manager = new PtyManager();
    const id = manager.spawn({ cwd: os.homedir(), shell: '/bin/sh', noTmux: true });
    expect(() => manager.resize(id, 120, 40)).not.toThrow();
  });

  it('spawn falls back to /bin/sh if shell not found', () => {
    manager = new PtyManager();
    const id = manager.spawn({ cwd: os.homedir(), shell: '/nonexistent/shell', noTmux: true });
    expect(id).toBeTruthy();
  });

  it('spawn falls back to homedir if cwd does not exist', () => {
    manager = new PtyManager();
    const id = manager.spawn({ cwd: '/nonexistent/path', shell: '/bin/sh', noTmux: true });
    expect(id).toBeTruthy();
  });
});
