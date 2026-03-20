export type ActivityStatus = 'idle' | 'running' | 'success' | 'error' | 'waiting';
type StatusCallback = (terminalId: string, status: ActivityStatus) => void;
type UrlCallback = (terminalId: string, url: string) => void;

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
const URL_DEBOUNCE_MS = 2000;

export class TerminalMonitor {
  private buffers = new Map<string, string>();
  private idleTimers = new Map<string, NodeJS.Timeout>();
  private debounceTimers = new Map<string, NodeJS.Timeout>();
  private lastStatus = new Map<string, ActivityStatus>();
  private callback: StatusCallback;
  private urlCallback?: UrlCallback;
  private detectedPorts = new Set<string>();
  private urlDebounceTimers = new Map<string, NodeJS.Timeout>();

  constructor(callback: StatusCallback, urlCallback?: UrlCallback) {
    this.callback = callback;
    this.urlCallback = urlCallback;
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

    // Detect localhost URLs (covers localhost, 127.0.0.1, [::], 0.0.0.0)
    const urlMatches = [...clean.matchAll(/https?:\/\/(?:localhost|127\.0\.0\.1|\[::\]|0\.0\.0\.0):(\d{3,5})/g)];
    // Also catch "port XXXX" patterns like Python's http.server
    const portOnlyMatches = [...clean.matchAll(/(?:port|Port)\s+(\d{3,5})/g)];
    const allMatches = [
      ...urlMatches.map((m) => ({ url: m[0], port: m[1] })),
      ...portOnlyMatches.map((m) => ({ url: `http://localhost:${m[1]}`, port: m[1] })),
    ];
    // Deduplicate by port
    const seenPorts = new Set<string>();
    for (const match of allMatches) {
      if (seenPorts.has(match.port)) continue;
      seenPorts.add(match.port);
      // Normalize URL to always use localhost
      const url = `http://localhost:${match.port}`;
      const port = match.port;
      const key = `${terminalId}:${port}`;
      if (this.detectedPorts.has(key)) continue;
      if (this.urlDebounceTimers.has(key)) continue;
      this.urlDebounceTimers.set(key, setTimeout(() => {
        this.detectedPorts.add(key);
        this.urlCallback?.(terminalId, url);
        this.urlDebounceTimers.delete(key);
      }, URL_DEBOUNCE_MS));
    }
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
    for (const [key, timer] of this.urlDebounceTimers) {
      if (key.startsWith(terminalId + ':')) {
        clearTimeout(timer);
        this.urlDebounceTimers.delete(key);
      }
    }
    for (const key of this.detectedPorts) {
      if (key.startsWith(terminalId + ':')) this.detectedPorts.delete(key);
    }
  }

  /** Clear a detected port so it can be re-detected */
  clearPort(port: string): void {
    for (const key of this.detectedPorts) {
      if (key.endsWith(':' + port)) this.detectedPorts.delete(key);
    }
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
