import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../projects/projects_provider.dart';
import '../../persistence/auto_save.dart';
import '../../core/database/database.dart';

final _memoryRefreshProvider = StateProvider<int>((ref) => 0);

class MemoryPanel extends ConsumerWidget {
  const MemoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    ref.watch(_memoryRefreshProvider); // rebuild trigger

    final projectState = ref.watch(projectsProvider);
    final group = projectState.groups
        .where((g) => g.id == projectState.activeGroupId)
        .firstOrNull;
    final cwd = group?.cwd;

    return FutureBuilder<_MemoryData>(
      future: _loadMemories(ref, cwd),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: Text('Loading...', style: TextStyle(color: theme.textSecondary, fontSize: 11)));
        }
        final data = snapshot.data!;
        if (data.pinned.isEmpty && data.project.isEmpty && data.global.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No memories yet.\nChat with Grace \u2014 she\'ll learn as you go.',
                style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.pinned.isNotEmpty) ...[
                _SectionHeader(label: '\u{1F4CC} Pinned (${data.pinned.length})', theme: theme),
                ...data.pinned.map((m) => _MemoryCard(memory: m, theme: theme, ref: ref)),
                const SizedBox(height: 12),
              ],
              if (data.project.isNotEmpty) ...[
                _SectionHeader(label: 'Project (${data.project.length})', theme: theme),
                ...data.project.map((m) => _MemoryCard(memory: m, theme: theme, ref: ref)),
                const SizedBox(height: 12),
              ],
              if (data.global.isNotEmpty) ...[
                _SectionHeader(label: 'Global (${data.global.length})', theme: theme),
                ...data.global.map((m) => _MemoryCard(memory: m, theme: theme, ref: ref)),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<_MemoryData> _loadMemories(WidgetRef ref, String? cwd) async {
    final db = ref.read(databaseProvider);
    final all = await db.graceMemoriesDao.getForProject(cwd);
    final pinned = all.where((m) => m.pinned).toList();
    final project = all.where((m) => !m.pinned && m.projectCwd != null).toList();
    final global = all.where((m) => !m.pinned && m.projectCwd == null).toList();
    return _MemoryData(pinned: pinned, project: project, global: global);
  }
}

class _MemoryData {
  final List<GraceMemory> pinned;
  final List<GraceMemory> project;
  final List<GraceMemory> global;
  _MemoryData({required this.pinned, required this.project, required this.global});
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final AppTheme theme;
  const _SectionHeader({required this.label, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

Color _categoryColor(String category) => switch (category) {
  'preference' => const Color(0xFF5B9BD5),
  'decision' => const Color(0xFF70AD47),
  'correction' => const Color(0xFFF4B942),
  'context' => const Color(0xFF9B59B6),
  'workflow' => const Color(0xFF1ABC9C),
  _ => const Color(0xFF89919A),
};

class _MemoryCard extends StatefulWidget {
  final GraceMemory memory;
  final AppTheme theme;
  final WidgetRef ref;
  const _MemoryCard({required this.memory, required this.theme, required this.ref});

  @override
  State<_MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<_MemoryCard> {
  bool _editing = false;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.memory.content);
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  void _refresh() => widget.ref.read(_memoryRefreshProvider.notifier).state++;

  Future<void> _togglePin() async {
    final db = widget.ref.read(databaseProvider);
    await db.graceMemoriesDao.setPinned(widget.memory.id, !widget.memory.pinned);
    _refresh();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete memory?'),
        content: Text(widget.memory.content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      final db = widget.ref.read(databaseProvider);
      await db.graceMemoriesDao.deleteMemory(widget.memory.id);
      _refresh();
    }
  }

  Future<void> _saveEdit() async {
    final newContent = _editCtrl.text.trim();
    if (newContent.isEmpty || newContent == widget.memory.content) {
      setState(() => _editing = false);
      return;
    }
    final db = widget.ref.read(databaseProvider);
    await db.graceMemoriesDao.updateMemory(widget.memory.id, content: newContent);
    setState(() => _editing = false);
    _refresh();
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final m = widget.memory;
    final catColor = _categoryColor(m.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.surfaceLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_editing)
              TextField(
                controller: _editCtrl,
                style: TextStyle(color: theme.textPrimary, fontSize: 11),
                maxLines: null,
                autofocus: true,
                onSubmitted: (_) => _saveEdit(),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              )
            else
              GestureDetector(
                onTap: () => setState(() => _editing = true),
                child: Text(
                  m.content.length > 200 ? '${m.content.substring(0, 200)}...' : m.content,
                  style: TextStyle(color: theme.textPrimary, fontSize: 11, height: 1.4),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(m.category, style: TextStyle(color: catColor, fontSize: 9, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text(_relativeTime(m.createdAt), style: TextStyle(color: theme.textSecondary, fontSize: 9)),
                const Spacer(),
                GestureDetector(
                  onTap: _togglePin,
                  child: Icon(
                    m.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 12,
                    color: m.pinned ? theme.accentBlue : theme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _delete,
                  child: Icon(Icons.close, size: 12, color: theme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
