import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/terminal_entry.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';
import '../projects/projects_provider.dart';
import '../terminal/terminal_provider.dart';
import 'command_palette.dart' show fuzzyScore;

class _TerminalResult {
  final TerminalEntry terminal;
  final String groupId;
  final String groupLabel;

  const _TerminalResult({
    required this.terminal,
    required this.groupId,
    required this.groupLabel,
  });
}

class QuickSwitcher extends ConsumerStatefulWidget {
  final bool open;
  final VoidCallback onClose;

  const QuickSwitcher({
    super.key,
    required this.open,
    required this.onClose,
  });

  @override
  ConsumerState<QuickSwitcher> createState() => _QuickSwitcherState();
}

class _QuickSwitcherState extends ConsumerState<QuickSwitcher> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(QuickSwitcher oldWidget) {
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

  List<_TerminalResult> _allResults() {
    final projectsState = ref.read(projectsProvider);
    final terminalsState = ref.read(terminalsProvider);
    final results = <_TerminalResult>[];

    for (final group in projectsState.groups) {
      for (final terminalId in group.terminalIds) {
        final terminal = terminalsState.terminals[terminalId];
        if (terminal != null) {
          results.add(
            _TerminalResult(
              terminal: terminal,
              groupId: group.id,
              groupLabel: group.label,
            ),
          );
        }
      }
    }
    return results;
  }

  List<_TerminalResult> _filteredResults() {
    final all = _allResults();
    final query = _controller.text.trim();
    if (query.isEmpty) return all;

    final scored = all
        .map((r) {
          final label = r.terminal.label ?? r.terminal.command;
          final labelScore = fuzzyScore(query, label);
          final cmdScore = fuzzyScore(query, r.terminal.command);
          final groupScore = fuzzyScore(query, r.groupLabel);
          final cwdScore = fuzzyScore(query, r.terminal.cwd);
          final best = [labelScore, cmdScore, groupScore, cwdScore]
              .reduce((a, b) => a > b ? a : b);
          return (result: r, score: best);
        })
        .where((e) => e.score > 0)
        .toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.result).toList();
  }

  void _switchTo(_TerminalResult result) {
    ref.read(projectsProvider.notifier).setActiveGroup(result.groupId);
    ref.read(terminalsProvider.notifier).setActiveTerminal(result.terminal.id);
    widget.onClose();
  }

  Color _statusColor(AppTheme theme, TerminalStatus status) {
    switch (status) {
      case TerminalStatus.running:
        return theme.accentGreen;
      case TerminalStatus.exited:
        return theme.accentRed;
      case TerminalStatus.active:
        return theme.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final theme = ref.watch(appThemeProvider);

    // Watch for state changes
    ref.watch(projectsProvider);
    ref.watch(terminalsProvider);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final filtered = _filteredResults();
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
                _switchTo(filtered[clampedIndex]);
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
                                  key: const Key('quick_switcher_input'),
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  autofocus: true,
                                  style: theme.titleStyle,
                                  decoration: InputDecoration(
                                    hintText: 'Switch to terminal...',
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
                                      _switchTo(filtered[clampedIndex]);
                                    }
                                  },
                                ),
                              ),
                              if (filtered.isNotEmpty) ...[
                                Divider(height: 1, color: theme.border, thickness: AppTheme.borderWidth),
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final r = filtered[index];
                                      final isSelected = index == clampedIndex;
                                      return _TerminalResultItem(
                                        result: r,
                                        statusColor:
                                            _statusColor(theme, r.terminal.status),
                                        isSelected: isSelected,
                                        onTap: () => _switchTo(r),
                                        theme: theme,
                                      );
                                    },
                                  ),
                                ),
                              ],
                              if (filtered.isEmpty && _controller.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                                  child: Text(
                                    'No terminals found',
                                    style: theme.dimStyle,
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
          ),
        );
      },
    );
  }
}

class _TerminalResultItem extends StatefulWidget {
  final _TerminalResult result;
  final Color statusColor;
  final bool isSelected;
  final VoidCallback onTap;
  final AppTheme theme;

  const _TerminalResultItem({
    required this.result,
    required this.statusColor,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_TerminalResultItem> createState() => _TerminalResultItemState();
}

class _TerminalResultItemState extends State<_TerminalResultItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final bg = (widget.isSelected || _hovered)
        ? theme.surfaceLight
        : theme.surface;
    final terminal = widget.result.terminal;
    final label = terminal.label ?? terminal.command;

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
                  color: widget.statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.bodyStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          widget.result.groupLabel,
                          style: theme.dimStyle.copyWith(color: theme.accentBlue, fontSize: 10),
                        ),
                        Text(
                          '  \u2022  ',
                          style: theme.dimStyle.copyWith(fontSize: 10),
                        ),
                        Expanded(
                          child: Text(
                            terminal.cwd,
                            style: theme.dimStyle.copyWith(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
