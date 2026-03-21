import 'package:dispatch_terminal/dispatch_terminal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';

/// A single terminal pane that wraps [TerminalView].
///
/// Each pane owns a [Terminal] controller. The [PtySession] is wired up during
/// app shell assembly (Task 15); until then the data stream is empty and input
/// is silently dropped.
class TerminalPane extends ConsumerStatefulWidget {
  final String terminalId;

  const TerminalPane({super.key, required this.terminalId});

  @override
  ConsumerState<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends ConsumerState<TerminalPane> {
  Terminal? _terminal;
  PtySession? _session;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(cols: 80, rows: 24);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    if (_terminal == null) {
      return const Center(child: Text('No terminal'));
    }

    return TerminalView(
      terminal: _terminal!,
      dataStream: _session?.dataStream ?? const Stream.empty(),
      onInput: (data) => _session?.write(data),
      fontSize: settings.fontSize,
      fontFamily: settings.fontFamily,
      theme: TerminalTheme.dark,
      autofocus: true,
      onResize: (cols, rows) => _session?.resize(cols, rows),
    );
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }
}
