import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class _Task {
  final String id;
  String title;
  bool done = false;

  _Task({required this.id, required this.title});
}

class TasksPanel extends StatefulWidget {
  const TasksPanel({super.key});

  @override
  State<TasksPanel> createState() => _TasksPanelState();
}

class _TasksPanelState extends State<TasksPanel> {
  final List<_Task> _tasks = [];
  bool _adding = false;
  final _addController = TextEditingController();
  final _addFocus = FocusNode();
  int _idCounter = 0;

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _startAdding() {
    _addController.clear();
    setState(() => _adding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addFocus.requestFocus();
    });
  }

  void _commitAdd() {
    final text = _addController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _tasks.add(_Task(id: 'task_${++_idCounter}', title: text));
      });
    }
    setState(() => _adding = false);
    _addController.clear();
  }

  void _cancelAdd() {
    setState(() => _adding = false);
    _addController.clear();
  }

  void _toggleTask(String id) {
    setState(() {
      final task = _tasks.firstWhere((t) => t.id == id);
      task.done = !task.done;
    });
  }

  void _deleteTask(String id) {
    setState(() => _tasks.removeWhere((t) => t.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dashed "Add Task" box
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingSm),
          child: GestureDetector(
            onTap: _startAdding,
            child: CustomPaint(
              painter: _DashedBorderPainter(color: AppTheme.border, radius: AppTheme.radius),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                child: const Text('+ Add Task', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _tasks.isEmpty && !_adding
              ? const _EmptyState(message: 'No tasks yet')
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (_adding) _buildAddRow(),
                    ..._tasks.map(
                      (task) => _TaskItem(
                        task: task,
                        onToggle: () => _toggleTask(task.id),
                        onDelete: () => _deleteTask(task.id),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAddRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: Icon(
              Icons.check_box_outline_blank,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _addController,
              focusNode: _addFocus,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'New task...',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
              ),
              onSubmitted: (_) => _commitAdd(),
            ),
          ),
          GestureDetector(
            onTap: _cancelAdd,
            child: const Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TaskItem extends StatefulWidget {
  final _Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskItem({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<_TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<_TaskItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: _hovered ? AppTheme.surfaceLight : Colors.transparent,
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onToggle,
              child: Icon(
                widget.task.done
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 16,
                color: widget.task.done
                    ? AppTheme.accentBlue
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.task.title,
                style: TextStyle(
                  color: widget.task.done
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                  fontSize: 12,
                  decoration: widget.task.done
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
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
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + dashWidth).clamp(0, metric.length).toDouble()), paint);
        d += dashWidth + dashSpace;
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
