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
    if (!containerRef.current) return;

    const term = new Terminal({
      theme: xtermTheme,
      fontSize: opts?.fontSize ?? 13,
      fontFamily: opts?.fontFamily ?? 'monospace',
      lineHeight: opts?.lineHeight ?? 1.2,
      cursorBlink: true,
      allowProposedApi: true,
    });

    const fit = new FitAddon();
    term.loadAddon(fit);

    term.open(containerRef.current);

    // Try WebGL, fall back to canvas
    try {
      const webgl = new WebglAddon();
      webgl.onContextLoss(() => webgl.dispose());
      term.loadAddon(webgl);
    } catch {
      // Canvas renderer is the default fallback
    }

    fit.fit();
    termRef.current = term;
    fitRef.current = fit;

    const resizeObserver = new ResizeObserver(() => fit.fit());
    resizeObserver.observe(containerRef.current);

    return () => {
      resizeObserver.disconnect();
      term.dispose();
      termRef.current = null;
      fitRef.current = null;
    };
  }, [containerRef, opts?.fontSize, opts?.fontFamily, opts?.lineHeight]);

  const fit = useCallback(() => fitRef.current?.fit(), []);

  return { terminal: termRef, fit };
}
