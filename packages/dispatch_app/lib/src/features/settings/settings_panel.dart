import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'settings_provider.dart';

class SettingsPanel extends ConsumerStatefulWidget {
  final bool open;
  final VoidCallback onClose;

  const SettingsPanel({
    super.key,
    required this.open,
    required this.onClose,
  });

  @override
  ConsumerState<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends ConsumerState<SettingsPanel> {
  late TextEditingController _shellController;
  late TextEditingController _fontFamilyController;
  late TextEditingController _screenshotFolderController;
  late double _fontSize;
  late double _lineHeight;
  late bool _notificationsEnabled;
  late bool _soundEnabled;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _shellController = TextEditingController();
    _fontFamilyController = TextEditingController();
    _screenshotFolderController = TextEditingController();
  }

  @override
  void dispose() {
    _shellController.dispose();
    _fontFamilyController.dispose();
    _screenshotFolderController.dispose();
    super.dispose();
  }

  void _initFromSettings(AppSettings settings) {
    _shellController.text = settings.shell;
    _fontFamilyController.text = settings.fontFamily;
    _screenshotFolderController.text = settings.screenshotFolder;
    _fontSize = settings.fontSize;
    _lineHeight = settings.lineHeight;
    _notificationsEnabled = settings.notificationsEnabled;
    _soundEnabled = settings.soundEnabled;
    _initialized = true;
  }

  void _save() {
    ref.read(settingsProvider.notifier).update(
      shell: _shellController.text,
      fontFamily: _fontFamilyController.text,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      notificationsEnabled: _notificationsEnabled,
      soundEnabled: _soundEnabled,
      screenshotFolder: _screenshotFolderController.text,
    );
    widget.onClose();
  }

  void _resetDefaults() {
    const defaults = AppSettings();
    setState(() {
      _shellController.text = defaults.shell;
      _fontFamilyController.text = defaults.fontFamily;
      _screenshotFolderController.text = defaults.screenshotFolder;
      _fontSize = defaults.fontSize;
      _lineHeight = defaults.lineHeight;
      _notificationsEnabled = defaults.notificationsEnabled;
      _soundEnabled = defaults.soundEnabled;
    });
  }

  @override
  void didUpdateWidget(SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      _initialized = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final settings = ref.watch(settingsProvider);

    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _initFromSettings(settings));
        }
      });
      _initFromSettings(settings);
    }

    return Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              color: Colors.black54,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Panel
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Material(
                color: AppTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTextField(
                              label: 'Shell Path',
                              controller: _shellController,
                              hint: '/bin/zsh',
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: 'Font Family',
                              controller: _fontFamilyController,
                              hint: 'JetBrains Mono',
                            ),
                            const SizedBox(height: 16),
                            _buildFontSizeRow(),
                            const SizedBox(height: 16),
                            _buildLineHeightRow(),
                            const SizedBox(height: 16),
                            _buildSwitchRow(
                              label: 'Notifications',
                              value: _notificationsEnabled,
                              onChanged: (v) =>
                                  setState(() => _notificationsEnabled = v),
                            ),
                            const SizedBox(height: 12),
                            _buildSwitchRow(
                              label: 'Sound',
                              value: _soundEnabled,
                              onChanged: (v) =>
                                  setState(() => _soundEnabled = v),
                            ),
                            const SizedBox(height: 16),
                            _buildScreenshotFolderRow(),
                          ],
                        ),
                      ),
                    ),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _resetDefaults,
            child: const Text(
              'Reset to Defaults',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.accentBlue),
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildFontSizeRow() {
    return Row(
      children: [
        const SizedBox(
          width: 100,
          child: Text(
            'Font Size',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: TextField(
            controller: TextEditingController(text: _fontSize.toStringAsFixed(0)),
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null && parsed >= 8 && parsed <= 24) {
                setState(() => _fontSize = parsed);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        const Text('(8–24)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildLineHeightRow() {
    return Row(
      children: [
        const SizedBox(
          width: 100,
          child: Text(
            'Line Height',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: TextField(
            controller: TextEditingController(text: _lineHeight.toStringAsFixed(1)),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null && parsed >= 1.0 && parsed <= 2.0) {
                setState(() => _lineHeight = parsed);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        const Text('(1.0–2.0)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
          ),
        ),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Container(
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: value ? AppTheme.accentBlue : AppTheme.surfaceLight,
              border: Border.all(color: value ? AppTheme.accentBlue : AppTheme.border),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotFolderRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Screenshot Folder',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _screenshotFolderController,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: '~/Pictures/Dispatch',
                  hintStyle:
                      const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        const BorderSide(color: AppTheme.accentBlue),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                'Browse',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
