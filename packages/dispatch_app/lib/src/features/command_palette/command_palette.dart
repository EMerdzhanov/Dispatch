import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/preset.dart';
import '../../core/theme/app_theme.dart';
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

  Color _dotColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      final value = int.parse(
        clean.length == 6 ? 'FF$clean' : clean,
        radix: 16,
      );
      return Color(value);
    } catch (_) {
      return AppTheme.textSecondary;
    }
  }

  void _spawn(Preset preset) {
    widget.onSpawn(preset.command, env: preset.env);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

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
                    maxWidth: 400,
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: Material(
                    color: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Input
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: TextField(
                            key: const Key('command_palette_input'),
                            controller: _controller,
                            focusNode: _focusNode,
                            autofocus: true,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search presets and actions...',
                              hintStyle: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
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
                          const Divider(
                            height: 1,
                            color: AppTheme.border,
                          ),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final preset = filtered[index];
                                final isSelected = index == clampedIndex;
                                return _PresetResultItem(
                                  preset: preset,
                                  dotColor: _dotColor(preset.color),
                                  isSelected: isSelected,
                                  onTap: () => _spawn(preset),
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

  const _PresetResultItem({
    required this.preset,
    required this.dotColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PresetResultItem> createState() => _PresetResultItemState();
}

class _PresetResultItemState extends State<_PresetResultItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = (widget.isSelected || _hovered)
        ? AppTheme.surfaceLight
        : AppTheme.surface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.preset.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      widget.preset.command,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
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
