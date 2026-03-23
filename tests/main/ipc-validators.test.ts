import { describe, it, expect } from 'vitest';
import { isValidTasks, isValidNotes, isValidVault } from '../../src/main/ipc-validators';

describe('IPC input validators', () => {
  describe('isValidTasks', () => {
    it('rejects non-array', () => {
      expect(isValidTasks('not an array')).toBe(false);
      expect(isValidTasks(null)).toBe(false);
      expect(isValidTasks(42)).toBe(false);
    });

    it('rejects tasks with missing fields', () => {
      expect(isValidTasks([{ id: '1' }])).toBe(false);
      expect(isValidTasks([{ id: '1', title: 'T' }])).toBe(false);
    });

    it('accepts valid tasks', () => {
      expect(isValidTasks([])).toBe(true);
      expect(isValidTasks([{ id: '1', title: 'Test', description: '', done: false }])).toBe(true);
    });
  });

  describe('isValidNotes', () => {
    it('rejects notes with missing fields', () => {
      expect(isValidNotes([{ id: '1' }])).toBe(false);
    });

    it('accepts valid notes', () => {
      expect(isValidNotes([])).toBe(true);
      expect(isValidNotes([{ id: '1', title: 'T', body: 'B', updatedAt: 1 }])).toBe(true);
    });
  });

  describe('isValidVault', () => {
    it('rejects entries with missing fields', () => {
      expect(isValidVault([{ id: '1', label: 'L' }])).toBe(false);
    });

    it('accepts valid vault entries', () => {
      expect(isValidVault([])).toBe(true);
      expect(isValidVault([{ id: '1', label: 'L', value: 'V' }])).toBe(true);
    });
  });
});
