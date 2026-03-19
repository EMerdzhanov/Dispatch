import React from 'react';
import { useStore } from '../store';
import { SplitContainer } from './SplitContainer';
import { TerminalPane } from './TerminalPane';
import { colors } from '../theme/colors';

interface TerminalAreaProps {
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

export function TerminalArea({ onSpawnInCwd }: TerminalAreaProps) {
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const splitLayout = useStore((s) => s.splitLayout);
  const zenMode = useStore((s) => s.zenMode);
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const hasTerminals = activeGroup && activeGroup.terminalIds.length > 0;

  if (!hasTerminals || !activeTerminalId) {
    return (
      <div style={{ flex: '1 1 0%', display: 'flex', alignItems: 'center', justifyContent: 'center', backgroundColor: colors.bg.primary }}>
        <div style={{ textAlign: 'center' }}>
          <p style={{ color: colors.text.dim }}>No terminal open</p>
          <p style={{ fontSize: 12, marginTop: 8, color: colors.text.dim }}>
            Use Quick Launch or press ⌘N
          </p>
        </div>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', flex: '1 1 0%', minHeight: 0, backgroundColor: colors.bg.primary }}>
      <TerminalPane key={activeTerminalId} terminalId={activeTerminalId} onSpawnInCwd={onSpawnInCwd} />
    </div>
  );
}
