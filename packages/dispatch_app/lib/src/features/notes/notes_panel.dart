import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class _Note {
  final String id;
  String title;
  String body;
  DateTime updatedAt;

  _Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
  });
}

class NotesPanel extends StatefulWidget {
  const NotesPanel({super.key});

  @override
  State<NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends State<NotesPanel> {
  final List<_Note> _notes = [];
  _Note? _editing;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _idCounter = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _addNote() {
    final note = _Note(
      id: 'note_${++_idCounter}',
      title: 'Untitled',
      body: '',
      updatedAt: DateTime.now(),
    );
    setState(() {
      _notes.insert(0, note);
      _openNote(note);
    });
  }

  void _openNote(_Note note) {
    _titleController.text = note.title;
    _bodyController.text = note.body;
    setState(() => _editing = note);
  }

  void _saveEditing() {
    if (_editing == null) return;
    setState(() {
      _editing!.title = _titleController.text.isEmpty
          ? 'Untitled'
          : _titleController.text;
      _editing!.body = _bodyController.text;
      _editing!.updatedAt = DateTime.now();
      _editing = null;
    });
  }

  void _deleteNote(String id) {
    setState(() {
      _notes.removeWhere((n) => n.id == id);
      if (_editing?.id == id) _editing = null;
    });
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
    if (_editing != null) {
      return _buildEditor();
    }
    return _buildList();
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: 'Notes',
          onAdd: _addNote,
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
  final _Note note;
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

class _PanelHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;

  const _PanelHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: AppTheme.borderWidth)),
      ),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: AppTheme.labelStyle,
          ),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: const Icon(Icons.add, size: 16, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
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
