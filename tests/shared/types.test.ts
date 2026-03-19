import { describe, it, expect } from 'vitest';
import {
  type Preset,
  type TerminalEntry,
  type ProjectGroup,
  type AppState,
  type SpawnOptions,
  TerminalStatus,
  DEFAULT_PRESETS,
} from '../../src/shared/types';

describe('shared types', () => {
  it('DEFAULT_PRESETS has 4 entries with required fields', () => {
    expect(DEFAULT_PRESETS).toHaveLength(4);
    for (const p of DEFAULT_PRESETS) {
      expect(p.name).toBeTruthy();
      expect(p.command).toBeTruthy();
      expect(p.color).toMatch(/^#/);
      expect(p.icon).toBeTruthy();
    }
  });

  it('TerminalStatus enum has all expected values', () => {
    expect(TerminalStatus.ACTIVE).toBe('ACTIVE');
    expect(TerminalStatus.RUNNING).toBe('RUNNING');
    expect(TerminalStatus.EXITED).toBe('EXITED');
    expect(TerminalStatus.EXTERNAL).toBe('EXTERNAL');
    expect(TerminalStatus.ATTACHING).toBe('ATTACHING');
  });
});
