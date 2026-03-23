import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alfa_orchestrator.dart';
import 'alfa_provider.dart';
import 'alfa_types.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';

class AlfaPanel extends ConsumerStatefulWidget {
  const AlfaPanel({super.key});

  @override
  ConsumerState<AlfaPanel> createState() => _AlfaPanelState();
}

class _AlfaPanelState extends ConsumerState<AlfaPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  String _streamingText = '';

  @override
  void initState() {
    super.initState();
    ref.listenManual(alfaProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });

      if (next.messages.isNotEmpty) {
        final last = next.messages.last;
        if (last is AlfaDeltaEvent) {
          setState(() => _streamingText += last.text);
        } else if (last is AlfaDoneEvent || last is AlfaMessageEvent) {
          setState(() => _streamingText = '');
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _streamingText = '';
    ref.read(alfaProvider.notifier).sendMessage(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alfaProvider);
    final theme = ref.watch(appThemeProvider);

    return Column(
      children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(bottom: BorderSide(color: theme.border)),
          ),
          child: Row(
            children: [
              _StatusDot(status: state.status, theme: theme),
              const SizedBox(width: 8),
              Text('ALFA', style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              )),
              const Spacer(),
              if (state.status != AlfaStatus.idle)
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: theme.accentBlue,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _buildDisplayItems(state.messages).length +
                (_streamingText.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              final items = _buildDisplayItems(state.messages);
              if (index == items.length && _streamingText.isNotEmpty) {
                return _MessageBubble(role: 'alfa', text: _streamingText, theme: theme);
              }
              if (index >= items.length) return const SizedBox.shrink();
              return items[index];
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(top: BorderSide(color: theme.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(color: theme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: state.configured
                        ? 'Talk to Alfa...'
                        : 'Set alfa.api_key in settings first',
                    hintStyle: TextStyle(color: theme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  enabled: state.configured,
                  onSubmitted: (_) => _send(),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send, size: 18, color: theme.accentBlue),
                onPressed: state.status == AlfaStatus.idle && state.configured ? _send : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDisplayItems(List<AlfaChatEvent> events) {
    final widgets = <Widget>[];
    final theme = ref.read(appThemeProvider);
    for (final event in events) {
      switch (event) {
        case HumanMessageEvent(:final text):
          widgets.add(_MessageBubble(role: 'human', text: text, theme: theme));
        case AlfaMessageEvent(:final text):
          widgets.add(_MessageBubble(role: 'alfa', text: text, theme: theme));
        case AlfaDoneEvent(:final text):
          widgets.add(_MessageBubble(role: 'alfa', text: text, theme: theme));
        case ToolCallEvent(:final name, :final isError):
          widgets.add(_ToolCallCard(name: name, isError: isError, theme: theme));
        case AlfaDeltaEvent():
          break;
      }
    }
    return widgets;
  }
}

class _StatusDot extends StatelessWidget {
  final AlfaStatus status;
  final AppTheme theme;
  const _StatusDot({required this.status, required this.theme});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AlfaStatus.idle => Colors.grey,
      AlfaStatus.thinking => Colors.blue,
      AlfaStatus.executing => Colors.orange,
      AlfaStatus.error => Colors.red,
    };
    return Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}

class _MessageBubble extends StatelessWidget {
  final String role;
  final String text;
  final AppTheme theme;
  const _MessageBubble({required this.role, required this.text, required this.theme});
  @override
  Widget build(BuildContext context) {
    final isHuman = role == 'human';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isHuman ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isHuman ? theme.accentBlue.withValues(alpha: 0.15) : theme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.border),
          ),
          child: SelectableText(text, style: TextStyle(color: theme.textPrimary, fontSize: 13)),
        ),
      ),
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  final String name;
  final bool isError;
  final AppTheme theme;
  const _ToolCallCard({required this.name, required this.isError, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, size: 14, color: isError ? Colors.red : Colors.green),
          const SizedBox(width: 6),
          Text(name, style: TextStyle(color: theme.textSecondary, fontSize: 11, fontFamily: 'JetBrains Mono')),
        ],
      ),
    );
  }
}
