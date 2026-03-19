import React from 'react';
import { useStore } from '../store';
import { SplitContainer } from './SplitContainer';
import { TerminalPane } from './TerminalPane';
import { colors } from '../theme/colors';

export function TerminalArea() {
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const splitLayout = useStore((s) => s.splitLayout);
  const zenMode = useStore((s) => s.zenMode);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const hasTerminals = activeGroup && activeGroup.terminalIds.length > 0;

  if (!hasTerminals || !activeTerminalId) {
    return (
      <div className="flex-1 flex items-center justify-center" style={{ backgroundColor: colors.bg.primary }}>
        <div className="text-center">
          <p style={{ color: colors.text.dim }}>No terminal open</p>
          <p className="text-xs mt-2" style={{ color: colors.text.dim }}>
            Use Quick Launch or press ⌘N
          </p>
        </div>
      </div>
    );
  }

  if (zenMode) {
    return (
      <div className="flex-1 flex flex-col overflow-hidden" style={{ backgroundColor: colors.bg.primary }}>
        <TerminalPane terminalId={activeTerminalId} />
      </div>
    );
  }

  if (splitLayout) {
    return (
      <div className="flex-1 flex overflow-hidden" style={{ backgroundColor: colors.bg.primary }}>
        <SplitContainer node={splitLayout} path={[]} />
      </div>
    );
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden" style={{ backgroundColor: colors.bg.primary }}>
      <TerminalPane terminalId={activeTerminalId} />
    </div>
  );
}
