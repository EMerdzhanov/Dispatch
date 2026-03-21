import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

class _Secret {
  final String id;
  String label;
  String value;
  bool visible = false;

  _Secret({
    required this.id,
    required this.label,
    required this.value,
  });
}

class VaultPanel extends StatefulWidget {
  const VaultPanel({super.key});

  @override
  State<VaultPanel> createState() => _VaultPanelState();
}

class _VaultPanelState extends State<VaultPanel> {
  final List<_Secret> _secrets = [];
  bool _adding = false;
  final _labelController = TextEditingController();
  final _valueController = TextEditingController();
  final _labelFocus = FocusNode();
  int _idCounter = 0;

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    _labelFocus.dispose();
    super.dispose();
  }

  void _startAdding() {
    _labelController.clear();
    _valueController.clear();
    setState(() => _adding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _labelFocus.requestFocus();
    });
  }

  void _commitAdd() {
    final label = _labelController.text.trim();
    final value = _valueController.text.trim();
    if (label.isNotEmpty && value.isNotEmpty) {
      setState(() {
        _secrets.add(
          _Secret(id: 'secret_${++_idCounter}', label: label, value: value),
        );
      });
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

  void _toggleVisibility(String id) {
    setState(() {
      final secret = _secrets.firstWhere((s) => s.id == id);
      secret.visible = !secret.visible;
    });
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
  }

  void _deleteSecret(String id) {
    setState(() => _secrets.removeWhere((s) => s.id == id));
  }

  @override
  Widget build(BuildContext context) {
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
                        onToggleVisibility: () =>
                            _toggleVisibility(secret.id),
                        onCopy: () => _copyToClipboard(secret.value),
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
  final _Secret secret;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const _SecretItem({
    required this.secret,
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
    final maskedValue = widget.secret.visible
        ? widget.secret.value
        : '••••••';

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
                icon: widget.secret.visible
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
