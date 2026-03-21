import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';
import 'browser_console.dart';

class BrowserPanel extends ConsumerStatefulWidget {
  final String url;

  const BrowserPanel({super.key, required this.url});

  @override
  ConsumerState<BrowserPanel> createState() => _BrowserPanelState();
}

class _BrowserPanelState extends ConsumerState<BrowserPanel> {
  late WebViewController _controller;
  String _currentUrl = '';
  bool _loading = true;
  final List<ConsoleMessage> _consoleMessages = [];
  bool _pipeToTerminal = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => setState(() { _loading = true; _currentUrl = url; }),
        onPageFinished: (url) => setState(() { _loading = false; _currentUrl = url; }),
      ))
      ..addJavaScriptChannel('ConsoleLog', onMessageReceived: (message) {
        _addConsoleMessage('info', message.message);
      })
      ..addJavaScriptChannel('ConsoleWarn', onMessageReceived: (message) {
        _addConsoleMessage('warn', message.message);
      })
      ..addJavaScriptChannel('ConsoleError', onMessageReceived: (message) {
        _addConsoleMessage('error', message.message);
      })
      ..loadRequest(Uri.parse(widget.url));

    // Inject console capture script after page loads
    _controller.setNavigationDelegate(NavigationDelegate(
      onPageStarted: (url) => setState(() { _loading = true; _currentUrl = url; }),
      onPageFinished: (url) {
        setState(() { _loading = false; _currentUrl = url; });
        _injectConsoleCapture();
      },
    ));
  }

  void _injectConsoleCapture() {
    _controller.runJavaScript('''
      (function() {
        var origLog = console.log, origWarn = console.warn, origError = console.error;
        console.log = function() {
          origLog.apply(console, arguments);
          try { ConsoleLog.postMessage(Array.from(arguments).map(String).join(' ')); } catch(e) {}
        };
        console.warn = function() {
          origWarn.apply(console, arguments);
          try { ConsoleWarn.postMessage(Array.from(arguments).map(String).join(' ')); } catch(e) {}
        };
        console.error = function() {
          origError.apply(console, arguments);
          try { ConsoleError.postMessage(Array.from(arguments).map(String).join(' ')); } catch(e) {}
        };
        window.onerror = function(msg, src, line) {
          try { ConsoleError.postMessage(msg + ' (' + src + ':' + line + ')'); } catch(e) {}
        };
      })();
    ''');
  }

  void _addConsoleMessage(String level, String message) {
    setState(() {
      _consoleMessages.add(ConsoleMessage(
        timestamp: DateTime.now(),
        level: level,
        message: message,
      ));
      // Keep max 500 messages
      if (_consoleMessages.length > 500) {
        _consoleMessages.removeAt(0);
      }
    });
  }

  @override
  void didUpdateWidget(BrowserPanel old) {
    super.didUpdateWidget(old);
    if (widget.url != old.url) {
      _currentUrl = widget.url;
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // URL bar with back/forward/reload
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _controller.goBack(),
                child: const Text('\u25C0', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _controller.goForward(),
                child: const Text('\u25B6', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _controller.reload(),
                child: const Text('\u21BB', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currentUrl,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_loading)
                const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentBlue),
                ),
            ],
          ),
        ),
        // WebView
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
        // Console panel
        BrowserConsole(
          messages: _consoleMessages,
          onClear: () => setState(() => _consoleMessages.clear()),
          pipeToTerminal: _pipeToTerminal,
          onTogglePipe: () => setState(() => _pipeToTerminal = !_pipeToTerminal),
        ),
      ],
    );
  }
}
