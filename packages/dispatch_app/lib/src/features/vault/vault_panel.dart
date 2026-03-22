import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
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
    final theme = AppTheme(ref.watch(activeThemeProvider));
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
              painter: _DashedBorderPainter(color: theme.border, radius: AppTheme.radius),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                child: Text('+ Add Secret', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _secrets.isEmpty && !_adding
              ? _EmptyState(message: 'No secrets stored', theme: theme)
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
                        theme: theme,
                      ),
                    ),
                    if (_adding) _buildAddForm(theme),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAddForm(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceLight,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _labelController,
            focusNode: _labelFocus,
            style: TextStyle(color: theme.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: BorderSide(color: theme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: BorderSide(color: theme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: BorderSide(color: theme.accentBlue),
              ),
              filled: true,
              fillColor: theme.surfaceLight,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              hintText: 'Label',
              hintStyle: TextStyle(color: theme.textSecondary),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _valueController,
            obscureText: true,
            style: TextStyle(color: theme.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: BorderSide(color: theme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: BorderSide(color: theme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                borderSide: BorderSide(color: theme.accentBlue),
              ),
              filled: true,
              fillColor: theme.surfaceLight,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              hintText: 'Value',
              hintStyle: TextStyle(color: theme.textSecondary),
            ),
            onSubmitted: (_) => _commitAdd(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _cancelAdd,
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _commitAdd,
                child: Text(
                  'Add',
                  style: TextStyle(color: theme.accentBlue, fontSize: 12),
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
  final AppTheme theme;

  const _SecretItem({
    required this.secret,
    required this.visible,
    required this.onToggleVisibility,
    required this.onCopy,
    required this.onDelete,
    required this.theme,
  });

  @override
  State<_SecretItem> createState() => _SecretItemState();
}

class _SecretItemState extends State<_SecretItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final maskedValue = widget.visible
        ? widget.secret.encryptedValue
        : '\u2022\u2022\u2022\u2022\u2022\u2022';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
                    widget.secret.label,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    maskedValue,
                    style: TextStyle(
                      color: theme.textSecondary,
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
                theme: theme,
              ),
              const SizedBox(width: 4),
              _IconButton(icon: Icons.copy, onTap: widget.onCopy, theme: theme),
              const SizedBox(width: 4),
              _IconButton(icon: Icons.close, onTap: widget.onDelete, theme: theme),
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
  final AppTheme theme;

  const _IconButton({required this.icon, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 14, color: theme.textSecondary),
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
