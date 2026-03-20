export type ActivityStatus = 'idle' | 'running' | 'success' | 'error' | 'waiting';
type StatusCallback = (terminalId: string, status: ActivityStatus) => void;

function stripAnsi(str: string): string {
  return str.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '');
}

const PATTERNS: { status: ActivityStatus; regex: RegExp }[] = [
  { status: 'error', regex: /\berror\b[^_]|\bfailed\b|\bFAIL\b|[✗❌]|exit code [1-9]/i },
  { status: 'success', regex: /[✓✅]|\bpassed\b|\bcompleted\b|Done!|All.*passed/i },
  { status: 'waiting', regex: /\?\s*$|\(y\/n\)|Continue\?|\bapprove\b|\bpermission\b/i },
];

const IDLE_TIMEOUT = 3000;
const DEBOUNCE_MS = 100;

export class TerminalMonitor {
  private buffers = new Map<string, string>();
  private idleTimers = new Map<string, NodeJS.Timeout>();
  private debounceTimers = new Map<string, NodeJS.Timeout>();
  private lastStatus = new Map<string, ActivityStatus>();
  private callback: StatusCallback;

  constructor(callback: StatusCallback) {
    this.callback = callback;
  }

  onData(terminalId: string, data: string): void {
    const existing = this.buffers.get(terminalId) || '';
    const updated = (existing + data).slice(-500);
    this.buffers.set(terminalId, updated);

    const clean = stripAnsi(data);
    let detected: ActivityStatus = 'running';

    for (const { status, regex } of PATTERNS) {
      if (regex.test(clean)) {
        detected = status;
        break;
      }
    }

    this.emitDebounced(terminalId, detected);
    this.resetIdleTimer(terminalId);
  }

  cleanup(terminalId: string): void {
    this.buffers.delete(terminalId);
    const idle = this.idleTimers.get(terminalId);
    if (idle) clearTimeout(idle);
    this.idleTimers.delete(terminalId);
    const debounce = this.debounceTimers.get(terminalId);
    if (debounce) clearTimeout(debounce);
    this.debounceTimers.delete(terminalId);
    this.lastStatus.delete(terminalId);
  }

  private emitDebounced(terminalId: string, status: ActivityStatus): void {
    const existing = this.debounceTimers.get(terminalId);
    if (existing) clearTimeout(existing);

    this.debounceTimers.set(terminalId, setTimeout(() => {
      if (this.lastStatus.get(terminalId) !== status) {
        this.lastStatus.set(terminalId, status);
        this.callback(terminalId, status);
      }
    }, DEBOUNCE_MS));
  }

  private resetIdleTimer(terminalId: string): void {
    const existing = this.idleTimers.get(terminalId);
    if (existing) clearTimeout(existing);

    this.idleTimers.set(terminalId, setTimeout(() => {
      this.emitDebounced(terminalId, 'idle');
    }, IDLE_TIMEOUT));
  }
}
