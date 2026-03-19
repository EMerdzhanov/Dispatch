import React from 'react';
import { useStore } from '../store';
import { colors } from '../theme/colors';

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
    <div
      style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '4px 10px',
        fontSize: 9, color: colors.text.dim,
        borderTop: `1px solid ${colors.border.subtle}`,
        flexShrink: 0,
      }}
    >
      <span
        style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', maxWidth: 160 }}
        title={cwd}
      >
        {shortPath(cwd) || 'No folder open'}
      </span>
      <span style={{ flexShrink: 0 }}>
        {totalCount} terminal{totalCount !== 1 ? 's' : ''}
      </span>
    </div>
  );
}
