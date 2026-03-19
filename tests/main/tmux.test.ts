import { describe, it, expect } from 'vitest';
import { TmuxHelper } from '../../src/main/tmux';

describe('TmuxHelper', () => {
  it('isAvailable returns a boolean', () => {
    const result = TmuxHelper.isAvailable();
    expect(typeof result).toBe('boolean');
  });

  it('listSessions returns an array', () => {
    const sessions = TmuxHelper.listSessions();
    expect(Array.isArray(sessions)).toBe(true);
  });

  it('getAttachCommand returns a valid command string', () => {
    const cmd = TmuxHelper.getAttachCommand('my-session');
    expect(cmd).toBe('tmux attach-session -t my-session');
  });
});
