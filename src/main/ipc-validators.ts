import type { Task, Note, VaultEntry } from '../shared/types';

export function isValidTasks(data: unknown): data is Task[] {
  return Array.isArray(data) && data.every(
    (t) => typeof t === 'object' && t !== null &&
      typeof (t as any).id === 'string' &&
      typeof (t as any).title === 'string' &&
      typeof (t as any).done === 'boolean'
  );
}

export function isValidNotes(data: unknown): data is Note[] {
  return Array.isArray(data) && data.every(
    (n) => typeof n === 'object' && n !== null &&
      typeof (n as any).id === 'string' &&
      typeof (n as any).title === 'string' &&
      typeof (n as any).body === 'string'
  );
}

export function isValidVault(data: unknown): data is VaultEntry[] {
  return Array.isArray(data) && data.every(
    (v) => typeof v === 'object' && v !== null &&
      typeof (v as any).id === 'string' &&
      typeof (v as any).label === 'string' &&
      typeof (v as any).value === 'string'
  );
}
