import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
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
        // URL bar
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
          ),
          child: Row(
            children: [
              // Reload button
              GestureDetector(
                onTap: () => _controller.reload(),
                child: const Icon(Icons.refresh, size: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
              // URL display
              Expanded(
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
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
      ],
    );
  }
}
