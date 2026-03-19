import React from 'react';
import { QuickLaunch } from './QuickLaunch';
import { TerminalList } from './TerminalList';
import { StatusBar } from './StatusBar';

interface SidebarProps {
  onSpawn: (command: string, env?: Record<string, string>) => void;
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

export function Sidebar({ onSpawn, onSpawnInCwd }: SidebarProps) {
  return (
    <div className="d-sidebar">
      <QuickLaunch onSpawn={onSpawn} />
      <TerminalList onSpawnInCwd={onSpawnInCwd} />
      <StatusBar />
    </div>
  );
}
