import React from 'react';
import { QuickLaunch } from './QuickLaunch';
import { TerminalList } from './TerminalList';
import { StatusBar } from './StatusBar';
import { colors } from '../theme/colors';

interface SidebarProps {
  onSpawn: (command: string, env?: Record<string, string>) => void;
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

export function Sidebar({ onSpawn, onSpawnInCwd }: SidebarProps) {
  return (
    <div
      className="flex flex-col h-full"
      style={{ backgroundColor: colors.bg.secondary, borderRight: `1px solid ${colors.border.default}` }}
    >
      <QuickLaunch onSpawn={onSpawn} />
      <TerminalList onSpawnInCwd={onSpawnInCwd} />
      <StatusBar />
    </div>
  );
}
