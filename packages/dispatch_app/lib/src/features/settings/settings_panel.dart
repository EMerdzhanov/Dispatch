import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/color_theme.dart';
import '../../core/models/preset.dart' as preset_model;
import '../../persistence/auto_save.dart';
import '../grace/grace_provider.dart';
import '../presets/presets_provider.dart';
import '../terminal/templates_provider.dart';
import 'settings_provider.dart';
import 'agent_status_panel.dart';

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

  // Grace settings
  late TextEditingController _graceApiKeyCtrl;
  late TextEditingController _graceModelCtrl;
  bool _graceLoaded = false;
  String? _graceStatus; // null = no status, 'saving', 'connected', 'error: ...'

  // Settings tab
  int _tabIndex = 0; // 0 = General, 1 = Agents

  bool _themeExpanded = false;

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
    _graceApiKeyCtrl = TextEditingController();
    _graceModelCtrl = TextEditingController(text: 'claude-sonnet-4-6');
  }

  @override
  void dispose() {
    _shellCtrl.dispose();
    _fontFamilyCtrl.dispose();
    _fontSizeCtrl.dispose();
    _lineHeightCtrl.dispose();
    _graceApiKeyCtrl.dispose();
    _graceModelCtrl.dispose();
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

    if (!_graceLoaded) {
      _graceLoaded = true;
      _loadGraceSettings();
    }
  }

  Future<void> _loadGraceSettings() async {
    final db = ref.read(databaseProvider);
    final apiKey = await db.settingsDao.getValue('grace.api_key');
    final model = await db.settingsDao.getValue('grace.model');
    if (mounted) {
      setState(() {
        if (apiKey != null) _graceApiKeyCtrl.text = apiKey;
        if (model != null) _graceModelCtrl.text = model;
      });
    }
  }

  Future<void> _saveGraceAndTest() async {
    final apiKey = _graceApiKeyCtrl.text.trim();
    final model = _graceModelCtrl.text.trim();

    if (apiKey.isEmpty) {
      setState(() => _graceStatus = 'error: API key is required');
      return;
    }

    setState(() => _graceStatus = 'saving');

    final db = ref.read(databaseProvider);
    await db.settingsDao.setValue('grace.api_key', apiKey);
    if (model.isNotEmpty) {
      await db.settingsDao.setValue('grace.model', model);
    }

    // Test the key with a minimal API call
    try {
      final testModel = model.isNotEmpty ? model : 'claude-sonnet-4-6';
      final body = '{"model":"$testModel","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}';

      final client = HttpClient();
      final request = await client.postUrl(
        Uri.https('api.anthropic.com', '/v1/messages'),
      );
      request.headers.set('content-type', 'application/json; charset=utf-8');
      request.headers.set('x-api-key', apiKey);
      request.headers.set('anthropic-version', '2023-06-01');
      request.add(utf8.encode(body));
      final response = await request.close();
      client.close();

      if (mounted) {
        if (response.statusCode == 200) {
          // Obscure the key after successful save
          final masked = '${apiKey.substring(0, 7)}..${apiKey.substring(apiKey.length - 4)}';
          _graceApiKeyCtrl.text = masked;
          setState(() => _graceStatus = 'connected');
          // Re-initialize Grace with the new key
          ref.read(graceProvider.notifier).initialize();
        } else if (response.statusCode == 401) {
          setState(() => _graceStatus = 'error: Invalid API key');
        } else {
          setState(() => _graceStatus = 'error: HTTP ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _graceStatus = 'error: $e');
      }
    }
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
    ref.read(themeProvider.notifier).setTheme('dispatch-dark');
    _themeExpanded = false;
  }

  @override
  void didUpdateWidget(SettingsPanel old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) { _initialized = false; _graceLoaded = false; }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final theme = ref.watch(appThemeProvider);
    final currentThemeId = ref.watch(themeProvider);
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
                    decoration: theme.overlayDecoration,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                children: [
                  // Header with tabs
                  Container(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 0),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text('Settings', style: theme.titleStyle.copyWith(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            GestureDetector(
                              onTap: widget.onClose,
                              child: Text('Close (Esc)', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _tabButton(theme, 'General', 0),
                            const SizedBox(width: 16),
                            _tabButton(theme, 'Agents', 1),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: _tabIndex == 1
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: const AgentStatusPanel(),
                          )
                        : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // === Terminal Section ===
                          _sectionTitle(theme, 'Terminal'),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SizedBox(
                                    width: 120,
                                    child: Text('Theme', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _themeExpanded = !_themeExpanded),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.surfaceLight,
                                        borderRadius: BorderRadius.circular(AppTheme.radius),
                                        border: Border.all(color: theme.border, width: AppTheme.borderWidth),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Always-visible selected theme row
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 10, height: 10,
                                                  margin: const EdgeInsets.only(right: 8),
                                                  decoration: BoxDecoration(
                                                    color: ColorTheme.fromId(currentThemeId).uiAccent,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    ColorTheme.fromId(currentThemeId).name,
                                                    style: TextStyle(color: theme.textPrimary, fontSize: 12),
                                                  ),
                                                ),
                                                Icon(
                                                  _themeExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                                  color: theme.textSecondary, size: 18,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Expandable options
                                          if (_themeExpanded)
                                            ...ColorTheme.builtIn.where((t) => t.id != currentThemeId).map((t) {
                                              return GestureDetector(
                                                onTap: () {
                                                  ref.read(themeProvider.notifier).setTheme(t.id);
                                                  setState(() => _themeExpanded = false);
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                  decoration: BoxDecoration(
                                                    border: Border(top: BorderSide(color: theme.border, width: AppTheme.borderWidth)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 10, height: 10,
                                                        margin: const EdgeInsets.only(right: 8),
                                                        decoration: BoxDecoration(
                                                          color: t.uiAccent,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      Text(t.name, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _settingsRow(theme, 'Font Family', _fontFamilyCtrl, wide: true),
                          _settingsRow(theme, 'Font Size', _fontSizeCtrl),
                          _settingsRow(theme, 'Line Height', _lineHeightCtrl),
                          _settingsRow(theme, 'Default Shell', _shellCtrl, wide: true),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _restoreDefaults,
                            child: Text('Restore Defaults', style: TextStyle(color: theme.accentBlue, fontSize: 12)),
                          ),

                          const SizedBox(height: 24),

                          // === Notifications Section ===
                          _sectionTitle(theme, 'Notifications'),
                          _toggleRow(theme, 'Desktop Notifications', _notificationsEnabled, (v) => setState(() { _notificationsEnabled = v; _save(); })),
                          _toggleRow(theme, 'Sound Effects', _soundEnabled, (v) => setState(() { _soundEnabled = v; _save(); })),

                          const SizedBox(height: 24),

                          // === Grace Section ===
                          _sectionTitle(theme, 'Grace'),
                          _settingsRow(theme, 'API Key', _graceApiKeyCtrl, wide: true),
                          _settingsRow(theme, 'Model', _graceModelCtrl, wide: true),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _graceStatus == 'saving' ? null : _saveGraceAndTest,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.accentBlue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _graceStatus == 'saving' ? 'Saving...' : 'Save & Connect',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_graceStatus == 'connected')
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('Connected', style: TextStyle(color: Colors.green, fontSize: 12)),
                                  ],
                                )
                              else if (_graceStatus != null && _graceStatus!.startsWith('error:'))
                                Flexible(
                                  child: Text(
                                    _graceStatus!.substring(7),
                                    style: TextStyle(color: theme.accentRed, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bring your own key. Get one at console.anthropic.com',
                            style: TextStyle(color: theme.textSecondary, fontSize: 10),
                          ),

                          const SizedBox(height: 24),

                          // === Quick Launch Presets Section ===
                          _sectionTitle(theme, 'Quick Launch Presets'),
                          ...List.generate(presets.length, (i) => _buildPresetRow(theme, presets, i)),
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
                              child: Text('+ Add Preset', style: TextStyle(color: theme.accentBlue, fontSize: 12)),
                            ),
                          ),

                          // === Templates Section ===
                          if (templates.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionTitle(theme, 'Saved Templates'),
                            ...List.generate(templates.length, (i) {
                              final t = templates[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.accentBlue)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(t.name, style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                                          Text(t.cwd, style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => ref.read(templatesProvider.notifier).removeTemplate(i),
                                      child: Text('Remove', style: TextStyle(color: theme.accentRed, fontSize: 11)),
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

  Widget _sectionTitle(AppTheme theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: theme.titleStyle.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _tabButton(AppTheme theme, String label, int index) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? theme.accentBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? theme.textPrimary : theme.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _settingsRow(AppTheme theme, String label, TextEditingController ctrl, {bool wide = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 12))),
          SizedBox(
            width: wide ? 220 : 80,
            child: TextField(
              controller: ctrl,
              style: TextStyle(color: theme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true, fillColor: theme.surfaceLight, isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.border)),
              ),
              onChanged: (_) => _save(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(AppTheme theme, String label, bool value, void Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 13))),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Container(
              width: 36, height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: value ? theme.accentBlue : theme.surfaceLight,
                border: Border.all(color: value ? theme.accentBlue : theme.border),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16, height: 16, margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: value ? Colors.white : theme.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetRow(AppTheme theme, List<preset_model.Preset> presets, int i) {
    final preset = presets[i];
    final isShell = preset.command == '\$SHELL';
    final isEditing = _editingIdx == i;

    if (isEditing) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _settingsRow(theme, 'Name', TextEditingController(text: _editName)..addListener(() {})),
            Row(
              children: [
                SizedBox(width: 120, child: Text('Name', style: TextStyle(color: theme.textSecondary, fontSize: 12))),
                SizedBox(
                  width: 220,
                  child: TextField(
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                    decoration: _inputDecor(theme),
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
                SizedBox(width: 120, child: Text('Command', style: TextStyle(color: theme.textSecondary, fontSize: 12))),
                SizedBox(
                  width: 220,
                  child: TextField(
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                    decoration: _inputDecor(theme, hint: 'e.g. claude --resume'),
                    controller: TextEditingController(text: _editCommand),
                    onChanged: (v) => _editCommand = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(width: 120, child: Text('Color', style: TextStyle(color: theme.textSecondary, fontSize: 12))),
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
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Text('Cancel', style: TextStyle(color: theme.textSecondary, fontSize: 12))),
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
                    decoration: BoxDecoration(color: theme.accentBlue, borderRadius: BorderRadius.circular(4)),
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
                Text(preset.name, style: TextStyle(color: theme.textPrimary, fontSize: 13)),
                Text(preset.command, style: TextStyle(color: theme.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          if (isShell)
            Text('default', style: TextStyle(color: theme.textSecondary, fontSize: 9))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() { _editingIdx = i; _editName = preset.name; _editCommand = preset.command; _editColor = preset.color; }),
                  child: Text('Edit', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => ref.read(presetsProvider.notifier).removePreset(i),
                  child: Text('Remove', style: TextStyle(color: theme.accentRed, fontSize: 11)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(AppTheme theme, {String? hint}) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: theme.textSecondary),
    filled: true, fillColor: theme.surfaceLight, isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.border)),
  );
}
