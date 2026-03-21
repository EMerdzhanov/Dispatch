import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../projects/projects_provider.dart';
import '../terminal/terminal_pane.dart';
import '../terminal/terminal_provider.dart';

const _fileIcons = <String, ({String icon, Color color})>{
  'ts':   (icon: 'TS', color: Color(0xFF3178C6)),
  'tsx':  (icon: 'TX', color: Color(0xFF3178C6)),
  'js':   (icon: 'JS', color: Color(0xFFF7DF1E)),
  'jsx':  (icon: 'JX', color: Color(0xFF61DAFB)),
  'dart': (icon: 'DT', color: Color(0xFF00B4AB)),
  'py':   (icon: 'PY', color: Color(0xFF3776AB)),
  'rb':   (icon: 'RB', color: Color(0xFFCC342D)),
  'go':   (icon: 'GO', color: Color(0xFF00ADD8)),
  'rs':   (icon: 'RS', color: Color(0xFFDEA584)),
  'json': (icon: '{}', color: Color(0xFFCBCB41)),
  'yaml': (icon: 'YM', color: Color(0xFFCB171E)),
  'yml':  (icon: 'YM', color: Color(0xFFCB171E)),
  'md':   (icon: 'M',  color: Color(0xFF519ABA)),
  'html': (icon: '<>', color: Color(0xFFE44D26)),
  'css':  (icon: '#',  color: Color(0xFF264DE4)),
  'sh':   (icon: '\$', color: Color(0xFF89E051)),
  'sql':  (icon: 'SQ', color: Color(0xFFE38C00)),
  'lock': (icon: 'LK', color: Color(0xFF89919A)),
  'txt':  (icon: 'T',  color: Color(0xFF89919A)),
};

({String icon, Color color}) _getFileIcon(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return _fileIcons[ext] ?? (icon: 'F', color: const Color(0xFF89919A));
}

class FileTree extends ConsumerStatefulWidget {
  const FileTree({super.key});

  @override
  ConsumerState<FileTree> createState() => _FileTreeState();
}

class _FileTreeState extends ConsumerState<FileTree> {
  List<FileSystemEntity>? _entries;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    final group = ref.read(projectsProvider).groups
        .where((g) => g.id == ref.read(projectsProvider).activeGroupId)
        .firstOrNull;
    final cwd = group?.cwd;
    if (cwd == null) { setState(() => _entries = []); return; }

    final dir = Directory(cwd);
    if (!dir.existsSync()) { setState(() => _entries = []); return; }

    final entries = dir.listSync()
        .where((e) => !e.path.split('/').last.startsWith('.'))
        .toList()
      ..sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir != bDir) return aDir ? -1 : 1;
        return a.path.split('/').last.compareTo(b.path.split('/').last);
      });
    setState(() => _entries = entries);
  }

  void _onFileClick(String filePath) {
    final activeId = ref.read(terminalsProvider).activeTerminalId;
    debugPrint('[FileTree] activeTerminalId=$activeId, registry keys=${TerminalPane.ptyRegistry.keys.toList()}');
    if (activeId == null) return;

    final pty = TerminalPane.ptyRegistry[activeId];
    debugPrint('[FileTree] pty for $activeId: ${pty != null ? "found" : "NULL"}');
    if (pty == null) return;

    // Shell-quote paths with spaces or special chars
    final needsQuoting = filePath.contains(' ') || RegExp(r'[()&;|<>$`!"\\#*?{}\[\]~]').hasMatch(filePath);
    final quoted = needsQuoting ? "'${filePath.replaceAll("'", "'\\''")}'" : filePath;
    debugPrint('[FileTree] writing: $quoted');
    pty.write(const Utf8Encoder().convert('$quoted '));
  }

  @override
  Widget build(BuildContext context) {
    // Reload when active group changes
    ref.listen(projectsProvider.select((s) => s.activeGroupId), (_, _) => _loadEntries());
    if (_entries == null) return const Center(child: Text('Loading...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)));
    if (_entries!.isEmpty) return const Center(child: Text('No files', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)));

    return ListView.builder(
      itemCount: _entries!.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final entity = _entries![index];
        final name = entity.path.split('/').last;
        final isDir = entity is Directory;
        return _TreeNode(name: name, fullPath: entity.path, isDirectory: isDir, depth: 0, onFileClick: _onFileClick);
      },
    );
  }
}

class _TreeNode extends StatefulWidget {
  final String name;
  final String fullPath;
  final bool isDirectory;
  final int depth;
  final void Function(String) onFileClick;

  const _TreeNode({required this.name, required this.fullPath, required this.isDirectory, required this.depth, required this.onFileClick});

  @override
  State<_TreeNode> createState() => _TreeNodeState();
}

class _TreeNodeState extends State<_TreeNode> {
  bool _expanded = false;
  bool _hovered = false;
  List<FileSystemEntity>? _children;

  void _toggle() {
    if (!widget.isDirectory) {
      widget.onFileClick(widget.fullPath);
      return;
    }
    if (!_expanded && _children == null) {
      final dir = Directory(widget.fullPath);
      if (dir.existsSync()) {
        final entries = dir.listSync()
            .where((e) => !e.path.split('/').last.startsWith('.'))
            .toList()
          ..sort((a, b) {
            final aDir = a is Directory;
            final bDir = b is Directory;
            if (aDir != bDir) return aDir ? -1 : 1;
            return a.path.split('/').last.compareTo(b.path.split('/').last);
          });
        _children = entries;
      }
    }
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: Material(
            color: _hovered ? AppTheme.surfaceLight : Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              child: Container(
                padding: EdgeInsets.only(left: AppTheme.spacingSm + widget.depth * 14, top: AppTheme.spacingXs, bottom: AppTheme.spacingXs, right: AppTheme.spacingSm),
              child: Row(
                children: [
                  if (widget.isDirectory) ...[
                    Text(_expanded ? '\u25BE' : '\u25B8', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                    const SizedBox(width: 4),
                    Text(_expanded ? '\u{1F4C2}' : '\u{1F4C1}', style: const TextStyle(fontSize: 12)),
                  ] else ...[
                    const SizedBox(width: 13),
                    () {
                      final fi = _getFileIcon(widget.name);
                      return Container(
                        width: 18,
                        alignment: Alignment.center,
                        child: Text(fi.icon, style: TextStyle(color: fi.color, fontSize: 8, fontWeight: FontWeight.w700)),
                      );
                    }(),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.name,
                      style: TextStyle(
                        color: _hovered ? AppTheme.textPrimary : (widget.isDirectory ? AppTheme.textPrimary : const Color(0xFFBBBBBB)),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
        if (_expanded && _children != null && widget.depth < 15)
          ..._children!.map((child) {
            final name = child.path.split('/').last;
            return _TreeNode(name: name, fullPath: child.path, isDirectory: child is Directory, depth: widget.depth + 1, onFileClick: widget.onFileClick);
          }),
      ],
    );
  }
}
