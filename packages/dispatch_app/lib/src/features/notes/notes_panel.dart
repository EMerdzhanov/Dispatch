import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../persistence/auto_save.dart';
import '../projects/projects_provider.dart';

class NotesPanel extends ConsumerStatefulWidget {
  const NotesPanel({super.key});

  @override
  ConsumerState<NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends ConsumerState<NotesPanel> {
  List<Note> _notes = [];
  Note? _editing;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _lastCwd;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String? _getActiveCwd() {
    final projects = ref.read(projectsProvider);
    final group = projects.groups
        .where((g) => g.id == projects.activeGroupId)
        .firstOrNull;
    return group?.cwd;
  }

  Future<void> _loadNotes() async {
    final cwd = _getActiveCwd();
    if (cwd == null) {
      setState(() => _notes = []);
      return;
    }
    final db = ref.read(databaseProvider);
    final notes = await db.notesDao.getNotesForProject(cwd);
    if (mounted) {
      setState(() {
        _notes = notes;
        _lastCwd = cwd;
      });
    }
  }

  Future<void> _addNote() async {
    final cwd = _getActiveCwd();
    if (cwd == null) return;
    final db = ref.read(databaseProvider);
    final id = await db.notesDao.insertNote(projectCwd: cwd, title: 'Untitled');
    await _loadNotes();
    // Open the newly created note for editing
    final newNote = _notes.where((n) => n.id == id).firstOrNull;
    if (newNote != null) {
      _openNote(newNote);
    }
  }

  void _openNote(Note note) {
    _titleController.text = note.title;
    _bodyController.text = note.body;
    setState(() => _editing = note);
  }

  Future<void> _saveEditing() async {
    if (_editing == null) return;
    final db = ref.read(databaseProvider);
    final title = _titleController.text.isEmpty
        ? 'Untitled'
        : _titleController.text;
    final body = _bodyController.text;
    await db.notesDao.updateNote(_editing!.id, title: title, body: body);
    setState(() => _editing = null);
    await _loadNotes();
  }

  Future<void> _deleteNote(int id) async {
    final db = ref.read(databaseProvider);
    await db.notesDao.deleteNote(id);
    if (_editing?.id == id) {
      setState(() => _editing = null);
    }
    await _loadNotes();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project changes and reload notes
    final projects = ref.watch(projectsProvider);
    final group = projects.groups
        .where((g) => g.id == projects.activeGroupId)
        .firstOrNull;
    final cwd = group?.cwd;

    if (cwd != _lastCwd) {
      _lastCwd = cwd;
      _editing = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotes());
    }

    if (_editing != null) {
      return _buildEditor();
    }
    return _buildList();
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dashed "Add Note" box
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingSm),
          child: GestureDetector(
            onTap: _addNote,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: AppTheme.border,
                  width: 1,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: CustomPaint(
                painter: _DashedBorderPainter(color: AppTheme.border, radius: AppTheme.radius),
                child: const Center(
                  child: Text(
                    '+ Add Note',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _notes.isEmpty
              ? const _EmptyState(message: 'No notes yet')
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return _NoteListItem(
                      note: note,
                      timeText: _formatTime(note.updatedAt),
                      onTap: () => _openNote(note),
                      onDelete: () => _deleteNote(note.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _saveEditing,
                child: const Icon(
                  Icons.arrow_back,
                  size: 16,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Note title',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _saveEditing,
                child: const Text(
                  'Done',
                  style: TextStyle(color: AppTheme.accentBlue, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Write your note here...',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteListItem extends StatefulWidget {
  final Note note;
  final String timeText;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteListItem({
    required this.note,
    required this.timeText,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_NoteListItem> createState() => _NoteListItemState();
}

class _NoteListItemState extends State<_NoteListItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _hovered ? AppTheme.surfaceLight : Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.note.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.timeText,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hovered)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    const dashWidth = 6.0;
    const dashSpace = 4.0;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end.toDouble()), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: AppTheme.dimStyle,
      ),
    );
  }
}
