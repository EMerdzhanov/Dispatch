import 'dart:async';
import 'dart:io';

enum TerminalActivityStatus { idle, running, success, error }

class TerminalMonitor {
  final Map<String, _MonitorState> _monitors = {};
  final void Function(String terminalId, TerminalActivityStatus status)?
      onStatusChange;
  final void Function(String terminalId, String url)? onUrlDetected;

  TerminalMonitor({this.onStatusChange, this.onUrlDetected});

  /// Feed data from a terminal's PTY output.
  void onData(String terminalId, String data) {
    final monitor = _monitors.putIfAbsent(terminalId, () => _MonitorState());
    monitor.lastDataTime = DateTime.now();

    // Detect localhost URLs
    final urlPattern = RegExp(r'https?://(localhost|127\.0\.0\.1)(:\d+)?');
    for (final match in urlPattern.allMatches(data)) {
      final url = match.group(0)!;
      if (!monitor.detectedUrls.contains(url)) {
        monitor.detectedUrls.add(url);
        onUrlDetected?.call(terminalId, url);
      }
    }

    // Detect success/error patterns
    final lowerData = data.toLowerCase();
    if (_isSuccessPattern(lowerData)) {
      _updateStatus(terminalId, TerminalActivityStatus.success);
    } else if (_isErrorPattern(lowerData)) {
      _updateStatus(terminalId, TerminalActivityStatus.error);
    } else {
      _updateStatus(terminalId, TerminalActivityStatus.running);
    }

    // Reset idle timer
    monitor.idleTimer?.cancel();
    monitor.idleTimer = Timer(const Duration(seconds: 2), () {
      _updateStatus(terminalId, TerminalActivityStatus.idle);
    });
  }

  bool _isSuccessPattern(String data) {
    return data.contains('✓') ||
        data.contains('done') ||
        data.contains('passed') ||
        data.contains('success') ||
        data.contains('complete') ||
        RegExp(r'exit code[:\s]*0').hasMatch(data);
  }

  bool _isErrorPattern(String data) {
    return data.contains('✗') ||
        data.contains('error') ||
        data.contains('failed') ||
        data.contains('fatal') ||
        data.contains('panic') ||
        RegExp(r'exit code[:\s]*[1-9]').hasMatch(data);
  }

  void _updateStatus(String terminalId, TerminalActivityStatus status) {
    final monitor = _monitors[terminalId];
    if (monitor == null || monitor.lastStatus == status) return;
    monitor.lastStatus = status;
    onStatusChange?.call(terminalId, status);
  }

  /// Open a URL in the system browser.
  static Future<void> openInBrowser(String url) async {
    await Process.run('open', [url]); // macOS
  }

  /// Send a macOS desktop notification.
  static Future<void> sendNotification({
    required String title,
    required String body,
  }) async {
    await Process.run('osascript', [
      '-e',
      'display notification "$body" with title "$title"',
    ]);
  }

  void cleanup(String terminalId) {
    _monitors[terminalId]?.idleTimer?.cancel();
    _monitors.remove(terminalId);
  }

  void disposeAll() {
    for (final m in _monitors.values) {
      m.idleTimer?.cancel();
    }
    _monitors.clear();
  }
}

class _MonitorState {
  DateTime lastDataTime = DateTime.now();
  TerminalActivityStatus? lastStatus;
  Timer? idleTimer;
  final Set<String> detectedUrls = {};
}
