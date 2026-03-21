import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../persistence/auto_save.dart';
import '../projects/projects_provider.dart';

class VaultPanel extends ConsumerStatefulWidget {
  const VaultPanel({super.key});

  @override
  ConsumerState<VaultPanel> createState() => _VaultPanelState();
}

class _VaultPanelState extends ConsumerState<VaultPanel> {
  List<VaultEntry> _secrets = [];
  final Set<int> _visibleIds = {};
  bool _adding = false;
  final _labelController = TextEditingController();
  final _valueController = TextEditingController();
  final _labelFocus = FocusNode();
  String? _lastCwd;

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    _labelFocus.dispose();
    super.dispose();
  }

  String? _getActiveCwd() {
    final projects = ref.read(projectsProvider);
    final group = projects.groups
        .where((g) => g.id == projects.activeGroupId)
        .firstOrNull;
    return group?.cwd;
  }

  Future<void> _loadEntries() async {
    final cwd = _getActiveCwd();
    if (cwd == null) {
      setState(() => _secrets = []);
      return;
    }
    final db = ref.read(databaseProvider);
    final entries = await db.vaultDao.getEntriesForProject(cwd);
    if (mounted) {
      setState(() {
        _secrets = entries;
        _lastCwd = cwd;
      });
    }
  }

  void _startAdding() {
    _labelController.clear();
    _valueController.clear();
    setState(() => _adding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _labelFocus.requestFocus();
    });
  }

  Future<void> _commitAdd() async {
    final label = _labelController.text.trim();
    final value = _valueController.text.trim();
    if (label.isNotEmpty && value.isNotEmpty) {
      final cwd = _getActiveCwd();
      if (cwd != null) {
        final db = ref.read(databaseProvider);
        await db.vaultDao.insertEntry(
          projectCwd: cwd,
          label: label,
          encryptedValue: value,
        );
        await _loadEntries();
      }
    }
    setState(() => _adding = false);
    _labelController.clear();
    _valueController.clear();
  }

  void _cancelAdd() {
    setState(() => _adding = false);
    _labelController.clear();
    _valueController.clear();
  }

  void _toggleVisibility(int id) {
    setState(() {
      if (_visibleIds.contains(id)) {
        _visibleIds.remove(id);
      } else {
        _visibleIds.add(id);
      }
    });
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
  }

  Future<void> _deleteSecret(int id) async {
    final db = ref.read(databaseProvider);
    await db.vaultDao.deleteEntry(id);
    _visibleIds.remove(id);
    await _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project changes and reload entries
    final projects = ref.watch(projectsProvider);
    final group = projects.groups
        .where((g) => g.id == projects.activeGroupId)
        .firstOrNull;
    final cwd = group?.cwd;

    if (cwd != _lastCwd) {
      _lastCwd = cwd;
      _visibleIds.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEntries());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dashed "Add Secret" box
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingSm),
          child: GestureDetector(
            onTap: _startAdding,
            child: CustomPaint(
              painter: _DashedBorderPainter(color: AppTheme.border, radius: AppTheme.radius),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                child: const Text('+ Add Secret', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _secrets.isEmpty && !_adding
              ? const _EmptyState(message: 'No secrets stored')
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ..._secrets.map(
                      (secret) => _SecretItem(
                        secret: secret,
                        visible: _visibleIds.contains(secret.id),
                        onToggleVisibility: () =>
                            _toggleVisibility(secret.id),
                        onCopy: () => _copyToClipboard(secret.encryptedValue),
                        onDelete: () => _deleteSecret(secret.id),
                      ),
                    ),
                    if (_adding) _buildAddForm(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAddForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _labelController,
            focusNode: _labelFocus,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: const BorderSide(color: AppTheme.accentBlue),
              ),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              hintText: 'Label',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _valueController,
            obscureText: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: const BorderSide(color: AppTheme.accentBlue),
              ),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              hintText: 'Value',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
            ),
            onSubmitted: (_) => _commitAdd(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _cancelAdd,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _commitAdd,
                child: const Text(
                  'Add',
                  style: TextStyle(color: AppTheme.accentBlue, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecretItem extends StatefulWidget {
  final VaultEntry secret;
  final bool visible;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const _SecretItem({
    required this.secret,
    required this.visible,
    required this.onToggleVisibility,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  State<_SecretItem> createState() => _SecretItemState();
}

class _SecretItemState extends State<_SecretItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final maskedValue = widget.visible
        ? widget.secret.encryptedValue
        : '\u2022\u2022\u2022\u2022\u2022\u2022';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
                    widget.secret.label,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    maskedValue,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_hovered) ...[
              _IconButton(
                icon: widget.visible
                    ? Icons.visibility_off
                    : Icons.visibility,
                onTap: widget.onToggleVisibility,
              ),
              const SizedBox(width: 4),
              _IconButton(icon: Icons.copy, onTap: widget.onCopy),
              const SizedBox(width: 4),
              _IconButton(icon: Icons.close, onTap: widget.onDelete),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 14, color: AppTheme.textSecondary),
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
