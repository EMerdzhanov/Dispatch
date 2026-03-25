import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'grace_provider.dart';
import 'grace_types.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_provider.dart';

class GracePanel extends ConsumerStatefulWidget {
  const GracePanel({super.key});

  @override
  ConsumerState<GracePanel> createState() => _GracePanelState();
}

class _GracePanelState extends ConsumerState<GracePanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  String _streamingText = '';

  @override
  void initState() {
    super.initState();
    ref.listenManual(graceProvider, (prev, next) {
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
        if (last is GraceDeltaEvent) {
          setState(() => _streamingText += last.text);
        } else if (last is GraceDoneEvent || last is GraceMessageEvent) {
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
    ref.read(graceProvider.notifier).sendMessage(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(graceProvider);
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
              Text('GRACE', style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              )),
              const Spacer(),
              if (state.status != GraceStatus.idle)
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
                return _MessageBubble(role: 'grace', text: _streamingText, theme: theme);
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
                        ? 'Talk to Grace...'
                        : 'Set grace.api_key in settings first',
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
                onPressed: state.status == GraceStatus.idle && state.configured ? _send : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDisplayItems(List<GraceChatEvent> events) {
    final widgets = <Widget>[];
    final theme = ref.read(appThemeProvider);
    for (final event in events) {
      switch (event) {
        case HumanMessageEvent(:final text):
          widgets.add(_MessageBubble(role: 'human', text: text, theme: theme));
        case GraceMessageEvent(:final text):
          widgets.add(_MessageBubble(role: 'grace', text: text, theme: theme));
        case GraceDoneEvent(:final text):
          widgets.add(_MessageBubble(role: 'grace', text: text, theme: theme));
        case ToolCallEvent(:final name, :final isError):
          widgets.add(_ToolCallCard(name: name, isError: isError, theme: theme));
        case GraceDeltaEvent():
          break;
      }
    }
    return widgets;
  }
}

class _StatusDot extends StatelessWidget {
  final GraceStatus status;
  final AppTheme theme;
  const _StatusDot({required this.status, required this.theme});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      GraceStatus.idle => Colors.grey,
      GraceStatus.thinking => Colors.blue,
      GraceStatus.executing => Colors.orange,
      GraceStatus.error => Colors.red,
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
          child: isHuman
              ? SelectableText(text, style: TextStyle(color: theme.textPrimary, fontSize: 13))
              : MarkdownBody(
                  data: text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: theme.textPrimary, fontSize: 13, height: 1.4),
                    h1: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    h2: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    h3: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    code: TextStyle(color: theme.accentBlue, fontSize: 12, fontFamily: 'JetBrains Mono', backgroundColor: theme.surfaceLight),
                    codeblockDecoration: BoxDecoration(color: theme.surfaceLight, borderRadius: BorderRadius.circular(4)),
                    codeblockPadding: const EdgeInsets.all(8),
                    listBullet: TextStyle(color: theme.textSecondary, fontSize: 13),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(left: BorderSide(color: theme.accentBlue, width: 3)),
                    ),
                    blockquotePadding: const EdgeInsets.only(left: 12),
                    a: TextStyle(color: theme.accentBlue, decoration: TextDecoration.underline),
                  ),
                ),
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
