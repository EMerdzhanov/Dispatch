import { describe, it, expect, vi, beforeEach } from 'vitest';
import { TerminalMonitor } from '../../src/main/terminal-monitor';

describe('TerminalMonitor', () => {
  let monitor: TerminalMonitor;
  let statusCallback: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    statusCallback = vi.fn();
    monitor = new TerminalMonitor(statusCallback);
  });

  it('detects running state on output', async () => {
    monitor.onData('t1', 'some output text');
    await new Promise((r) => setTimeout(r, 150));
    expect(statusCallback).toHaveBeenCalledWith('t1', 'running');
  });

  it('detects error patterns', async () => {
    monitor.onData('t1', 'Error: something failed');
    await new Promise((r) => setTimeout(r, 150));
    expect(statusCallback).toHaveBeenCalledWith('t1', 'error');
  });

  it('detects success patterns', async () => {
    monitor.onData('t1', 'All tests passed ✓');
    await new Promise((r) => setTimeout(r, 150));
    expect(statusCallback).toHaveBeenCalledWith('t1', 'success');
  });

  it('detects waiting patterns', async () => {
    monitor.onData('t1', 'Do you want to continue? (y/n)');
    await new Promise((r) => setTimeout(r, 150));
    expect(statusCallback).toHaveBeenCalledWith('t1', 'waiting');
  });

  it('transitions to idle after timeout', async () => {
    monitor.onData('t1', 'some output');
    await new Promise((r) => setTimeout(r, 3500));
    expect(statusCallback).toHaveBeenCalledWith('t1', 'idle');
  });

  it('strips ANSI codes before matching', async () => {
    monitor.onData('t1', '\x1b[31mError:\x1b[0m bad thing');
    await new Promise((r) => setTimeout(r, 150));
    expect(statusCallback).toHaveBeenCalledWith('t1', 'error');
  });

  it('cleanup removes terminal timers', () => {
    monitor.onData('t1', 'output');
    monitor.cleanup('t1');
    expect(() => monitor.cleanup('t1')).not.toThrow();
  });
});
