import { useEffect, useRef, useCallback } from 'react';
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import { WebglAddon } from 'xterm-addon-webgl';
import { xtermTheme } from '../theme/xterm-theme';

interface UseTerminalOptions {
  fontSize?: number;
  fontFamily?: string;
  lineHeight?: number;
}

export function useTerminal(containerRef: React.RefObject<HTMLDivElement | null>, opts?: UseTerminalOptions) {
  const termRef = useRef<Terminal | null>(null);
  const fitRef = useRef<FitAddon | null>(null);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    // Don't re-create if already initialized
    if (termRef.current) return;

    const term = new Terminal({
      theme: xtermTheme,
      fontSize: opts?.fontSize ?? 13,
      fontFamily: opts?.fontFamily ?? "'Menlo', 'Monaco', 'Courier New', monospace",
      lineHeight: opts?.lineHeight ?? 1.2,
      cursorBlink: true,
      allowProposedApi: true,
      convertEol: true,
    });

    const fit = new FitAddon();
    term.loadAddon(fit);

    term.open(container);

    // Try WebGL, fall back to canvas
    try {
      const webgl = new WebglAddon();
      webgl.onContextLoss(() => webgl.dispose());
      term.loadAddon(webgl);
    } catch {
      // Canvas renderer is the default fallback
    }

    termRef.current = term;
    fitRef.current = fit;

    // Fit after a short delay to ensure container has dimensions
    const fitTimer = setTimeout(() => {
      try { fit.fit(); } catch { /* ignore if container not ready */ }
    }, 100);

    // Also fit on subsequent resizes
    const resizeObserver = new ResizeObserver(() => {
      try { fit.fit(); } catch { /* ignore */ }
    });
    resizeObserver.observe(container);

    return () => {
      clearTimeout(fitTimer);
      resizeObserver.disconnect();
      term.dispose();
      termRef.current = null;
      fitRef.current = null;
    };
  }, []);  // Only run once on mount

  const fit = useCallback(() => {
    try { fitRef.current?.fit(); } catch { /* ignore */ }
  }, []);

  return { terminal: termRef, fit };
}
