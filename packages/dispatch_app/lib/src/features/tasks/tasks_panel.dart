import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../persistence/auto_save.dart';
import '../projects/projects_provider.dart';

class TasksPanel extends ConsumerStatefulWidget {
  const TasksPanel({super.key});

  @override
  ConsumerState<TasksPanel> createState() => _TasksPanelState();
}

class _TasksPanelState extends ConsumerState<TasksPanel> {
  List<Task> _tasks = [];
  bool _adding = false;
  int? _expandedId;
  final _addController = TextEditingController();
  final _addFocus = FocusNode();
  String? _lastCwd;

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  String? _getActiveCwd() {
    final projects = ref.read(projectsProvider);
    final group = projects.groups
        .where((g) => g.id == projects.activeGroupId)
        .firstOrNull;
    return group?.cwd;
  }

  Future<void> _loadTasks() async {
    final cwd = _getActiveCwd();
    if (cwd == null) {
      setState(() => _tasks = []);
      return;
    }
    final db = ref.read(databaseProvider);
    final tasks = await db.tasksDao.getTasksForProject(cwd);
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _lastCwd = cwd;
      });
    }
  }

  void _startAdding() {
    _addController.clear();
    setState(() => _adding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addFocus.requestFocus();
    });
  }

  Future<void> _commitAdd() async {
    final text = _addController.text.trim();
    if (text.isNotEmpty) {
      final cwd = _getActiveCwd();
      if (cwd != null) {
        final db = ref.read(databaseProvider);
        await db.tasksDao.insertTask(projectCwd: cwd, title: text);
        await _loadTasks();
      }
    }
    setState(() => _adding = false);
    _addController.clear();
  }

  void _cancelAdd() {
    setState(() => _adding = false);
    _addController.clear();
  }

  Future<void> _toggleTask(int id) async {
    final db = ref.read(databaseProvider);
    await db.tasksDao.toggleDone(id);
    await _loadTasks();
  }

  Future<void> _updateDescription(int id, String description) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.tasks)..where((t) => t.id.equals(id)))
        .write(TasksCompanion(description: Value(description)));
    await _loadTasks();
  }

  Future<void> _deleteTask(int id) async {
    final db = ref.read(databaseProvider);
    await db.tasksDao.deleteTask(id);
    if (_expandedId == id) _expandedId = null;
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project changes and reload tasks
    final projects = ref.watch(projectsProvider);
    final group = projects.groups
        .where((g) => g.id == projects.activeGroupId)
        .firstOrNull;
    final cwd = group?.cwd;

    if (cwd != _lastCwd) {
      _lastCwd = cwd;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTasks());
    }

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
                        expanded: _expandedId == task.id,
                        onToggle: () => _toggleTask(task.id),
                        onTitleTap: () => setState(() {
                          _expandedId = _expandedId == task.id ? null : task.id;
                        }),
                        onDescriptionChanged: (desc) => _updateDescription(task.id, desc),
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
  final Task task;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onTitleTap;
  final void Function(String) onDescriptionChanged;
  final VoidCallback onDelete;

  const _TaskItem({
    required this.task,
    required this.expanded,
    required this.onToggle,
    required this.onTitleTap,
    required this.onDescriptionChanged,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: _hovered || widget.expanded ? AppTheme.surfaceLight : Colors.transparent,
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
                  child: GestureDetector(
                    onTap: widget.onTitleTap,
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
                ),
                if (_hovered)
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: const Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          // Expandable description
          if (widget.expanded)
            Container(
              color: AppTheme.surfaceLight,
              padding: const EdgeInsets.only(left: 36, right: 12, bottom: 8),
              child: TextField(
                controller: TextEditingController(text: widget.task.description),
                maxLines: 3,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Add description...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                onChanged: widget.onDescriptionChanged,
              ),
            ),
        ],
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
