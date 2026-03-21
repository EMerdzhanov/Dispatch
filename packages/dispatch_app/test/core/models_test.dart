import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_app/src/core/models/project_group.dart';
import 'package:dispatch_app/src/core/models/terminal_entry.dart';
import 'package:dispatch_app/src/core/models/preset.dart';
import 'package:dispatch_app/src/core/models/split_node.dart';
import 'package:dispatch_app/src/core/models/template.dart';

void main() {
  group('TerminalEntry', () {
    test('creates with required fields', () {
      final entry = TerminalEntry(
        id: 'abc', command: 'claude', cwd: '/home', status: TerminalStatus.running,
      );
      expect(entry.id, 'abc');
      expect(entry.status, TerminalStatus.running);
    });

    test('copyWith changes status', () {
      final entry = TerminalEntry(id: 'a', command: 'sh', cwd: '/', status: TerminalStatus.running);
      final exited = entry.copyWith(status: TerminalStatus.exited, exitCode: 0);
      expect(exited.status, TerminalStatus.exited);
      expect(exited.exitCode, 0);
      expect(exited.command, 'sh');
    });
  });

  group('ProjectGroup', () {
    test('creates with terminal IDs list', () {
      final group = ProjectGroup(id: 'g1', label: 'myproject', cwd: '/code/myproject', terminalIds: ['t1', 't2']);
      expect(group.terminalIds.length, 2);
      expect(group.label, 'myproject');
    });
  });

  group('Preset', () {
    test('default presets list is non-empty', () {
      expect(Preset.defaults.length, 4);
      expect(Preset.defaults[0].name, 'Claude Code');
    });
  });

  group('SplitNode', () {
    test('leaf holds terminal ID', () {
      const leaf = SplitLeaf(terminalId: 't1');
      expect(leaf.terminalId, 't1');
    });

    test('branch holds two children with ratio', () {
      const branch = SplitBranch(
        direction: SplitDirection.horizontal,
        ratio: 0.5,
        children: (SplitLeaf(terminalId: 't1'), SplitLeaf(terminalId: 't2')),
      );
      expect(branch.ratio, 0.5);
      expect(branch.children.$1.terminalId, 't1');
    });

    test('buildEqualSplit with 2 terminals creates branch', () {
      final layout = SplitNode.buildEqualSplit(['a', 'b'], SplitDirection.horizontal);
      expect(layout, isA<SplitBranch>());
      final branch = layout as SplitBranch;
      expect(branch.ratio, 0.5);
    });

    test('buildEqualSplit with 3 terminals creates nested tree', () {
      final layout = SplitNode.buildEqualSplit(['a', 'b', 'c'], SplitDirection.vertical);
      expect(layout, isA<SplitBranch>());
    });

    test('buildEqualSplit with 1 terminal returns leaf', () {
      final layout = SplitNode.buildEqualSplit(['a'], SplitDirection.horizontal);
      expect(layout, isA<SplitLeaf>());
    });
  });

  group('Template', () {
    test('creates with name and cwd', () {
      final t = Template(name: 'dev', cwd: '/code');
      expect(t.name, 'dev');
      expect(t.layout, isNull);
    });
  });
}
