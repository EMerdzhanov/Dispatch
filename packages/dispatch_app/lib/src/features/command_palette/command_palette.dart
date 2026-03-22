import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/preset.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../presets/presets_provider.dart';

/// Scores how well [query] matches [target].
/// Returns > 0 for a match, 0 for no match.
int fuzzyScore(String query, String target) {
  final q = query.toLowerCase();
  final t = target.toLowerCase();
  if (q.isEmpty) return 100;
  if (t.contains(q)) return 100 - t.indexOf(q); // exact substring
  // Check if all chars of query appear in order in target
  int qi = 0;
  for (int ti = 0; ti < t.length && qi < q.length; ti++) {
    if (t[ti] == q[qi]) qi++;
  }
  return qi == q.length ? 50 : 0; // partial fuzzy match
}

class CommandPalette extends ConsumerStatefulWidget {
  final bool open;
  final VoidCallback onClose;
  final void Function(String command, {Map<String, String>? env}) onSpawn;

  const CommandPalette({
    super.key,
    required this.open,
    required this.onClose,
    required this.onSpawn,
  });

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(CommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      _controller.clear();
      _selectedIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Preset> _filteredPresets(List<Preset> presets) {
    final query = _controller.text.trim();
    if (query.isEmpty) return presets;

    final scored = presets
        .map((p) {
          final nameScore = fuzzyScore(query, p.name);
          final cmdScore = fuzzyScore(query, p.command);
          final best = nameScore > cmdScore ? nameScore : cmdScore;
          return (preset: p, score: best);
        })
        .where((e) => e.score > 0)
        .toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.preset).toList();
  }

  Color _dotColor(AppTheme theme, String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      final value = int.parse(
        clean.length == 6 ? 'FF$clean' : clean,
        radix: 16,
      );
      return Color(value);
    } catch (_) {
      return theme.textSecondary;
    }
  }

  void _spawn(Preset preset) {
    widget.onSpawn(preset.command, env: preset.env);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final theme = AppTheme(ref.watch(activeThemeProvider));
    final presets = ref.watch(presetsProvider).presets;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final filtered = _filteredPresets(presets);
        final clampedIndex =
            filtered.isEmpty ? 0 : _selectedIndex.clamp(0, filtered.length - 1);

        return KeyboardListener(
          focusNode: FocusNode(),
          autofocus: false,
          onKeyEvent: (event) {
            if (event is! KeyDownEvent) return;
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              widget.onClose();
            } else if (event.logicalKey == LogicalKeyboardKey.enter) {
              if (filtered.isNotEmpty) {
                _spawn(filtered[clampedIndex]);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              setState(() {
                _selectedIndex =
                    (clampedIndex + 1).clamp(0, filtered.length - 1);
              });
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              setState(() {
                _selectedIndex =
                    (clampedIndex - 1).clamp(0, filtered.length - 1);
              });
            }
          },
          child: Stack(
            children: [
              // Backdrop with blur
              GestureDetector(
                onTap: widget.onClose,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              // Panel with slide-in
              Center(
                child: AnimatedSlide(
                  offset: Offset(0, widget.open ? 0 : -0.02),
                  duration: AppTheme.animDuration,
                  curve: AppTheme.animCurve,
                  child: AnimatedOpacity(
                    opacity: widget.open ? 1.0 : 0.0,
                    duration: AppTheme.animFastDuration,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 400,
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: theme.overlayDecoration,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Input
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingLg,
                                  vertical: AppTheme.spacingMd,
                                ),
                                child: TextField(
                                  key: const Key('command_palette_input'),
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  autofocus: true,
                                  style: theme.titleStyle,
                                  decoration: InputDecoration(
                                    hintText: 'Search presets and actions...',
                                    hintStyle: theme.titleStyle.copyWith(color: theme.textSecondary),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (_) {
                                    setState(() {
                                      _selectedIndex = 0;
                                    });
                                  },
                                  onSubmitted: (_) {
                                    if (filtered.isNotEmpty) {
                                      _spawn(filtered[clampedIndex]);
                                    }
                                  },
                                ),
                              ),
                              if (filtered.isNotEmpty) ...[
                                Divider(
                                  height: 1,
                                  color: theme.border,
                                  thickness: AppTheme.borderWidth,
                                ),
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final preset = filtered[index];
                                      final isSelected = index == clampedIndex;
                                      return _PresetResultItem(
                                        preset: preset,
                                        dotColor: _dotColor(theme, preset.color),
                                        isSelected: isSelected,
                                        onTap: () => _spawn(preset),
                                        theme: theme,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PresetResultItem extends StatefulWidget {
  final Preset preset;
  final Color dotColor;
  final bool isSelected;
  final VoidCallback onTap;
  final AppTheme theme;

  const _PresetResultItem({
    required this.preset,
    required this.dotColor,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_PresetResultItem> createState() => _PresetResultItemState();
}

class _PresetResultItemState extends State<_PresetResultItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final bg = (widget.isSelected || _hovered)
        ? theme.surfaceLight
        : theme.surface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingSm),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.preset.name,
                      style: theme.bodyStyle,
                    ),
                    Text(
                      widget.preset.command,
                      style: theme.dimStyle.copyWith(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
