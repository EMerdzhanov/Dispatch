import { describe, it, expect } from 'vitest';
import os from 'os';
import path from 'path';

function isWithinHome(targetPath: string): boolean {
  const resolved = path.resolve(targetPath);
  const home = os.homedir();
  return resolved === home || resolved.startsWith(home + '/');
}

describe('path restriction', () => {
  it('allows paths within home directory', () => {
    expect(isWithinHome(os.homedir())).toBe(true);
    expect(isWithinHome(path.join(os.homedir(), 'Documents'))).toBe(true);
    expect(isWithinHome(path.join(os.homedir(), 'Projects', 'app'))).toBe(true);
  });

  it('rejects paths outside home directory', () => {
    expect(isWithinHome('/etc/passwd')).toBe(false);
    expect(isWithinHome('/tmp/evil')).toBe(false);
    expect(isWithinHome('/')).toBe(false);
  });

  it('rejects paths that look like home but are not (prefix attack)', () => {
    const fakeHome = os.homedir() + 'evil';
    expect(isWithinHome(fakeHome)).toBe(false);
  });
});
