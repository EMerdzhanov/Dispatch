import React from 'react';
import { QuickLaunch } from './QuickLaunch';
import { TerminalList } from './TerminalList';
import { StatusBar } from './StatusBar';
import { colors } from '../theme/colors';

interface SidebarProps {
  onSpawn: (command: string, env?: Record<string, string>) => void;
}

export function Sidebar({ onSpawn }: SidebarProps) {
  return (
    <div
      className="flex flex-col h-full"
      style={{ backgroundColor: colors.bg.secondary, borderRight: `1px solid ${colors.border.default}` }}
    >
      <QuickLaunch onSpawn={onSpawn} />
      <TerminalList />
      <StatusBar />
    </div>
  );
}
