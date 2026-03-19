import { describe, it, expect } from 'vitest';
import { ProcessScanner } from '../../src/main/process-scanner';

describe('ProcessScanner', () => {
  it('instantiates without error', () => {
    const scanner = new ProcessScanner();
    expect(scanner).toBeDefined();
  });

  it('scan returns an array', async () => {
    const scanner = new ProcessScanner();
    const results = await scanner.scan();
    expect(Array.isArray(results)).toBe(true);
  });

  it('results have pid, command, and cwd fields', async () => {
    const scanner = new ProcessScanner();
    const results = await scanner.scan();
    for (const r of results) {
      expect(typeof r.pid).toBe('number');
      expect(typeof r.command).toBe('string');
      expect(typeof r.cwd).toBe('string');
    }
  });
});
