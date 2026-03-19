import React from 'react';
import { useStore } from '../store';

/** Show at most N path segments, truncated from the start with … */
function shortPath(fullPath: string | undefined, maxLen = 28): string {
  if (!fullPath) return '';
  if (fullPath.length <= maxLen) return fullPath;
  // Try to show the last 2 segments
  const parts = fullPath.replace(/\/$/, '').split('/');
  const tail = parts.slice(-2).join('/');
  return tail.length < maxLen ? `…/${tail}` : `…/${parts[parts.length - 1]}`;
}

export function StatusBar() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const totalCount = activeGroup?.terminalIds.length ?? 0;
  const cwd = activeGroup?.cwd;

  return (
    <div className="d-statusbar">
      <span className="d-statusbar__path" title={cwd}>
        {shortPath(cwd) || 'No folder open'}
      </span>
      <span style={{ flexShrink: 0 }}>
        {totalCount} terminal{totalCount !== 1 ? 's' : ''}
      </span>
    </div>
  );
}
