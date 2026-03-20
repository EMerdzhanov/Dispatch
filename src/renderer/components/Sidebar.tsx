import React from 'react';
import { QuickLaunch } from './QuickLaunch';
import { TerminalList } from './TerminalList';
import { StatusBar } from './StatusBar';
import { ProjectPanel } from './ProjectPanel';

interface SidebarProps {
  onSpawn: (command: string, env?: Record<string, string>) => void;
  onSpawnInCwd?: (cwd: string, command?: string) => void;
}

export function Sidebar({ onSpawn, onSpawnInCwd }: SidebarProps) {
  return (
    <div className="d-sidebar">
      <div style={{ display: 'flex', flexDirection: 'column', flex: '0 0 60%', minHeight: 0, overflow: 'hidden' }}>
        <QuickLaunch onSpawn={onSpawn} />
        <TerminalList />
        <StatusBar />
      </div>
      <ProjectPanel />
    </div>
  );
}
