import { describe, it, expect, beforeEach } from 'vitest';
import { useStore } from '../../src/renderer/store';
import { TerminalStatus } from '../../src/shared/types';

describe('useStore', () => {
  beforeEach(() => {
    useStore.setState(useStore.getInitialState());
  });

  it('starts with empty state', () => {
    const state = useStore.getState();
    expect(state.groups).toEqual([]);
    expect(state.terminals).toEqual({});
    expect(state.activeGroupId).toBeNull();
  });

  it('addGroup creates a new project group', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const { groups } = useStore.getState();
    expect(groups).toHaveLength(1);
    expect(groups[0].label).toBe('foo');
    expect(groups[0].cwd).toBe('~/Projects/foo');
  });

  it('addTerminal adds a terminal to a group', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const groupId = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(groupId, {
      id: 't1',
      command: 'claude',
      cwd: '~/Projects/foo',
      status: TerminalStatus.RUNNING,
    });
    const { terminals, groups } = useStore.getState();
    expect(terminals['t1']).toBeDefined();
    expect(groups[0].terminalIds).toContain('t1');
  });

  it('setActiveTerminal updates active state', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const groupId = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(groupId, {
      id: 't1',
      command: 'claude',
      cwd: '~/Projects/foo',
      status: TerminalStatus.RUNNING,
    });
    useStore.getState().setActiveTerminal('t1');
    expect(useStore.getState().activeTerminalId).toBe('t1');
    expect(useStore.getState().terminals['t1'].status).toBe(TerminalStatus.ACTIVE);
  });

  it('removeTerminal cleans up terminal and group reference', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const groupId = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(groupId, {
      id: 't1',
      command: 'claude',
      cwd: '~/Projects/foo',
      status: TerminalStatus.RUNNING,
    });
    useStore.getState().removeTerminal('t1');
    expect(useStore.getState().terminals['t1']).toBeUndefined();
    expect(useStore.getState().groups[0].terminalIds).not.toContain('t1');
  });

  it('updateTerminalStatus changes status', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const groupId = useStore.getState().groups[0].id;
    useStore.getState().addTerminal(groupId, {
      id: 't1',
      command: 'claude',
      cwd: '~/Projects/foo',
      status: TerminalStatus.RUNNING,
    });
    useStore.getState().updateTerminalStatus('t1', TerminalStatus.EXITED, 0);
    const t = useStore.getState().terminals['t1'];
    expect(t.status).toBe(TerminalStatus.EXITED);
    expect(t.exitCode).toBe(0);
  });

  it('findOrCreateGroup returns existing group for same cwd', () => {
    useStore.getState().addGroup('~/Projects/foo', 'foo');
    const existing = useStore.getState().groups[0].id;
    const found = useStore.getState().findOrCreateGroup('~/Projects/foo');
    expect(found).toBe(existing);
  });

  it('findOrCreateGroup creates new group for unknown cwd', () => {
    const id = useStore.getState().findOrCreateGroup('~/Projects/bar');
    expect(useStore.getState().groups).toHaveLength(1);
    expect(useStore.getState().groups[0].id).toBe(id);
  });
});
