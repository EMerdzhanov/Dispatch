import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/preset.dart' as preset_model;
import '../presets/presets_provider.dart';
import '../terminal/templates_provider.dart';
import 'settings_provider.dart';

const _presetColors = [
  '#0f3460', '#e94560', '#f5a623', '#4caf50',
  '#53a8ff', '#c678dd', '#56b6c2', '#888888',
];

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse(h, radix: 16) + 0xFF000000);
}

class SettingsPanel extends ConsumerStatefulWidget {
  final bool open;
  final VoidCallback onClose;

  const SettingsPanel({super.key, required this.open, required this.onClose});

  @override
  ConsumerState<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends ConsumerState<SettingsPanel> {
  late TextEditingController _shellCtrl;
  late TextEditingController _fontFamilyCtrl;
  late TextEditingController _fontSizeCtrl;
  late TextEditingController _lineHeightCtrl;
  late bool _notificationsEnabled;
  late bool _soundEnabled;

  // Preset editing state
  int? _editingIdx;
  String _editName = '';
  String _editCommand = '';
  String _editColor = '#888888';

  @override
  void initState() {
    super.initState();
    _shellCtrl = TextEditingController();
    _fontFamilyCtrl = TextEditingController();
    _fontSizeCtrl = TextEditingController();
    _lineHeightCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _shellCtrl.dispose();
    _fontFamilyCtrl.dispose();
    _fontSizeCtrl.dispose();
    _lineHeightCtrl.dispose();
    super.dispose();
  }

  bool _initialized = false;

  void _loadSettings(AppSettings s) {
    _shellCtrl.text = s.shell;
    _fontFamilyCtrl.text = s.fontFamily;
    _fontSizeCtrl.text = s.fontSize.toStringAsFixed(0);
    _lineHeightCtrl.text = s.lineHeight.toStringAsFixed(1);
    _notificationsEnabled = s.notificationsEnabled;
    _soundEnabled = s.soundEnabled;
    _initialized = true;
  }

  void _save() {
    ref.read(settingsProvider.notifier).update(
      shell: _shellCtrl.text,
      fontFamily: _fontFamilyCtrl.text,
      fontSize: double.tryParse(_fontSizeCtrl.text) ?? 13,
      lineHeight: double.tryParse(_lineHeightCtrl.text) ?? 1.2,
      notificationsEnabled: _notificationsEnabled,
      soundEnabled: _soundEnabled,
    );
  }

  void _restoreDefaults() {
    const d = AppSettings();
    setState(() => _loadSettings(d));
    ref.read(settingsProvider.notifier).update(
      shell: d.shell, fontFamily: d.fontFamily, fontSize: d.fontSize,
      lineHeight: d.lineHeight, notificationsEnabled: d.notificationsEnabled,
      soundEnabled: d.soundEnabled,
    );
  }

  @override
  void didUpdateWidget(SettingsPanel old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) _initialized = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final settings = ref.watch(settingsProvider);
    if (!_initialized) _loadSettings(settings);

    final presets = ref.watch(presetsProvider).presets;
    final templates = ref.watch(templatesProvider);

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),
        Center(
          child: AnimatedSlide(
            offset: Offset(0, widget.open ? 0 : -0.02),
            duration: AppTheme.animDuration,
            curve: AppTheme.animCurve,
            child: AnimatedOpacity(
              opacity: widget.open ? 1.0 : 0.0,
              duration: AppTheme.animFastDuration,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.of(context).size.height * 0.85),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: AppTheme.overlayDecoration,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
                    child: Row(
                      children: [
                        Text('Settings', style: AppTheme.titleStyle.copyWith(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: const Text('Close (Esc)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // === Terminal Section ===
                          _sectionTitle('Terminal'),
                          _settingsRow('Font Family', _fontFamilyCtrl, wide: true),
                          _settingsRow('Font Size', _fontSizeCtrl),
                          _settingsRow('Line Height', _lineHeightCtrl),
                          _settingsRow('Default Shell', _shellCtrl, wide: true),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _restoreDefaults,
                            child: const Text('Restore Defaults', style: TextStyle(color: AppTheme.accentBlue, fontSize: 12)),
                          ),

                          const SizedBox(height: 24),

                          // === Notifications Section ===
                          _sectionTitle('Notifications'),
                          _toggleRow('Desktop Notifications', _notificationsEnabled, (v) => setState(() { _notificationsEnabled = v; _save(); })),
                          _toggleRow('Sound Effects', _soundEnabled, (v) => setState(() { _soundEnabled = v; _save(); })),

                          const SizedBox(height: 24),

                          // === Quick Launch Presets Section ===
                          _sectionTitle('Quick Launch Presets'),
                          ...List.generate(presets.length, (i) => _buildPresetRow(presets, i)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              final newPreset = preset_model.Preset(name: 'New Preset', command: 'claude', color: '#53a8ff', icon: 'terminal');
                              ref.read(presetsProvider.notifier).addPreset(newPreset);
                              setState(() {
                                _editingIdx = presets.length;
                                _editName = newPreset.name;
                                _editCommand = newPreset.command;
                                _editColor = newPreset.color;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: const Text('+ Add Preset', style: TextStyle(color: AppTheme.accentBlue, fontSize: 12)),
                            ),
                          ),

                          // === Templates Section ===
                          if (templates.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionTitle('Saved Templates'),
                            ...List.generate(templates.length, (i) {
                              final t = templates[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentBlue)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(t.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                                          Text(t.cwd, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => ref.read(templatesProvider.notifier).removeTemplate(i),
                                      child: const Text('Remove', style: TextStyle(color: AppTheme.accentRed, fontSize: 11)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: AppTheme.titleStyle.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _settingsRow(String label, TextEditingController ctrl, {bool wide = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          SizedBox(
            width: wide ? 220 : 80,
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true, fillColor: AppTheme.surfaceLight, isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.border)),
              ),
              onChanged: (_) => _save(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, void Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Container(
              width: 36, height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: value ? AppTheme.accentBlue : AppTheme.surfaceLight,
                border: Border.all(color: value ? AppTheme.accentBlue : AppTheme.border),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16, height: 16, margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: value ? Colors.white : AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetRow(List<preset_model.Preset> presets, int i) {
    final preset = presets[i];
    final isShell = preset.command == '\$SHELL';
    final isEditing = _editingIdx == i;

    if (isEditing) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _settingsRow('Name', TextEditingController(text: _editName)..addListener(() {})),
            Row(
              children: [
                const SizedBox(width: 120, child: Text('Name', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                SizedBox(
                  width: 220,
                  child: TextField(
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecor(),
                    controller: TextEditingController(text: _editName),
                    onChanged: (v) => _editName = v,
                    autofocus: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 120, child: Text('Command', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                SizedBox(
                  width: 220,
                  child: TextField(
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecor(hint: 'e.g. claude --resume'),
                    controller: TextEditingController(text: _editCommand),
                    onChanged: (v) => _editCommand = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 120, child: Text('Color', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                Wrap(
                  spacing: 4,
                  children: _presetColors.map((c) {
                    return GestureDetector(
                      onTap: () => setState(() => _editColor = c),
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: _hexToColor(c),
                          border: _editColor == c ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _editingIdx = null),
                  child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                ),
                GestureDetector(
                  onTap: () {
                    if (_editName.trim().isEmpty || _editCommand.trim().isEmpty) return;
                    final updated = List<preset_model.Preset>.from(presets);
                    updated[i] = preset_model.Preset(name: _editName.trim(), command: _editCommand.trim(), color: _editColor, icon: preset.icon);
                    ref.read(presetsProvider.notifier).setPresets(updated);
                    setState(() => _editingIdx = null);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.accentBlue, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _hexToColor(preset.color))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preset.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                Text(preset.command, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          if (isShell)
            const Text('default', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() { _editingIdx = i; _editName = preset.name; _editCommand = preset.command; _editColor = preset.color; }),
                  child: const Text('Edit', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => ref.read(presetsProvider.notifier).removePreset(i),
                  child: const Text('Remove', style: TextStyle(color: AppTheme.accentRed, fontSize: 11)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor({String? hint}) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: AppTheme.textSecondary),
    filled: true, fillColor: AppTheme.surfaceLight, isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.border)),
  );
}
