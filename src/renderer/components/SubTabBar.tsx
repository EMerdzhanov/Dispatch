import React from 'react';
import { useStore } from '../store';

export function SubTabBar() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const browserTabs = useStore((s) => s.browserTabs);
  const activeBrowserTabId = useStore((s) => s.activeBrowserTabId);
  const setActiveBrowserTab = useStore((s) => s.setActiveBrowserTab);
  const removeBrowserTab = useStore((s) => s.removeBrowserTab);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const groupBrowserTabs = (activeGroup?.browserTabIds || [])
    .map((id) => browserTabs[id]).filter(Boolean);

  if (groupBrowserTabs.length === 0) return null;

  return (
    <div className="d-subtabs">
      <button
        className={`d-subtab${activeBrowserTabId === null ? ' d-subtab--active' : ''}`}
        onClick={() => setActiveBrowserTab(null)}
      >
        Terminals
      </button>
      {groupBrowserTabs.map((tab) => {
        let host = tab.url;
        try { host = new URL(tab.url).host; } catch {}
        return (
          <button
            key={tab.id}
            className={`d-subtab${activeBrowserTabId === tab.id ? ' d-subtab--active' : ''}`}
            onClick={() => setActiveBrowserTab(tab.id)}
          >
            🌐 {tab.title || host}
            <span className="d-subtab__close" onClick={(e) => {
              e.stopPropagation();
              if (activeGroupId) removeBrowserTab(activeGroupId, tab.id);
            }}>✕</span>
          </button>
        );
      })}
    </div>
  );
}
