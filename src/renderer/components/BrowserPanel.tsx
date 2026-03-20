declare global {
  namespace JSX {
    interface IntrinsicElements {
      webview: React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement> & {
        src?: string;
        preload?: string;
        nodeintegration?: string;
        allowpopups?: string;
      }, HTMLElement>;
    }
  }
}

import React, { useRef, useEffect, useState } from 'react';
import { useStore } from '../store';
import { BrowserConsole } from './BrowserConsole';

interface BrowserPanelProps {
  tabId: string;
}

export function BrowserPanel({ tabId }: BrowserPanelProps) {
  const tab = useStore((s) => s.browserTabs[tabId]);
  const addConsoleMessage = useStore((s) => s.addConsoleMessage);
  const webviewRef = useRef<any>(null);
  const [urlInput, setUrlInput] = useState(tab?.url || '');
  const [canGoBack, setCanGoBack] = useState(false);
  const [canGoForward, setCanGoForward] = useState(false);

  useEffect(() => {
    if (tab) setUrlInput(tab.url);
  }, [tab?.url]);

  useEffect(() => {
    const webview = webviewRef.current;
    if (!webview) return;

    const handleConsole = (e: any) => {
      const levelMap: Record<number, 'info' | 'warn' | 'error'> = { 0: 'info', 1: 'info', 2: 'warn', 3: 'error' };
      addConsoleMessage(tabId, {
        timestamp: Date.now(),
        level: levelMap[e.level] || 'info',
        message: e.message,
        source: e.sourceId,
        line: e.line,
      });
    };

    const handleNavigation = () => {
      try {
        setCanGoBack(webview.canGoBack());
        setCanGoForward(webview.canGoForward());
        setUrlInput(webview.getURL());
      } catch {}
    };

    // webview events need to be attached after dom-ready
    const handleReady = () => {
      handleNavigation();
    };

    webview.addEventListener('console-message', handleConsole);
    webview.addEventListener('did-navigate', handleNavigation);
    webview.addEventListener('did-navigate-in-page', handleNavigation);
    webview.addEventListener('dom-ready', handleReady);

    return () => {
      try {
        webview.removeEventListener('console-message', handleConsole);
        webview.removeEventListener('did-navigate', handleNavigation);
        webview.removeEventListener('did-navigate-in-page', handleNavigation);
        webview.removeEventListener('dom-ready', handleReady);
      } catch {}
    };
  }, [tabId]);

  if (!tab) return null;

  const navigate = (url: string) => {
    let normalized = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      normalized = 'http://' + url;
    }
    if (webviewRef.current) {
      webviewRef.current.src = normalized;
    }
    setUrlInput(normalized);
  };

  return (
    <div className="d-browser">
      <div className="d-browser__toolbar">
        <button className="d-browser__nav-btn" disabled={!canGoBack}
          onClick={() => { try { webviewRef.current?.goBack(); } catch {} }}>◀</button>
        <button className="d-browser__nav-btn" disabled={!canGoForward}
          onClick={() => { try { webviewRef.current?.goForward(); } catch {} }}>▶</button>
        <button className="d-browser__nav-btn"
          onClick={() => { try { webviewRef.current?.reload(); } catch {} }}>↻</button>
        <input
          className="d-browser__url"
          value={urlInput}
          onChange={(e) => setUrlInput(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') navigate(urlInput); }}
        />
      </div>
      <webview
        ref={webviewRef}
        src={tab.url}
        style={{ flex: '1 1 0%', minHeight: 0, border: 'none' }}
      />
      <BrowserConsole tabId={tabId} />
    </div>
  );
}
