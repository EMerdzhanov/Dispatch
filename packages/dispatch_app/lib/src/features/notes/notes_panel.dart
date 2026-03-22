import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
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
    final theme = ref.watch(appThemeProvider);
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
      return _buildEditor(theme);
    }
    return _buildList(theme);
  }

  Widget _buildList(AppTheme theme) {
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
                  color: theme.border,
                  width: 1,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: CustomPaint(
                painter: _DashedBorderPainter(color: theme.border, radius: AppTheme.radius),
                child: Center(
                  child: Text(
                    '+ Add Note',
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _notes.isEmpty
              ? _EmptyState(message: 'No notes yet', theme: theme)
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
                      theme: theme,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEditor(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(bottom: BorderSide(color: theme.border)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _saveEditing,
                child: Icon(
                  Icons.arrow_back,
                  size: 16,
                  color: theme.accentBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Note title',
                    hintStyle: TextStyle(color: theme.textSecondary),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _saveEditing,
                child: Text(
                  'Done',
                  style: TextStyle(color: theme.accentBlue, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: theme.surface,
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Write your note here...',
                hintStyle: TextStyle(color: theme.textSecondary),
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
  final AppTheme theme;

  const _NoteListItem({
    required this.note,
    required this.timeText,
    required this.onTap,
    required this.onDelete,
    required this.theme,
  });

  @override
  State<_NoteListItem> createState() => _NoteListItemState();
}

class _NoteListItemState extends State<_NoteListItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _hovered ? theme.surfaceLight : Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.note.title,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.timeText,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hovered)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: theme.textSecondary,
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
  final AppTheme theme;

  const _EmptyState({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: theme.dimStyle,
      ),
    );
  }
}
