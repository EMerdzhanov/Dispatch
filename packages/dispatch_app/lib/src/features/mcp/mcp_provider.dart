import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mcp_server.dart';
import 'mcp_notifications.dart';
import '../../persistence/auto_save.dart';

class McpServerState {
  final bool enabled;
  final bool running;
  final int port;
  final bool authEnabled;
  final String? authToken;
  final bool bindAll;
  final int connectionCount;
  final List<McpActivityEntry> activityLog;
  final bool tunnelRunning;
  final bool tunnelStarting;
  final String? tunnelUrl;
  final bool cloudflaredAvailable;

  const McpServerState({
    this.enabled = false,
    this.running = false,
    this.port = 3900,
    this.authEnabled = false,
    this.authToken,
    this.bindAll = false,
    this.connectionCount = 0,
    this.activityLog = const [],
    this.tunnelRunning = false,
    this.tunnelStarting = false,
    this.tunnelUrl,
    this.cloudflaredAvailable = false,
  });

  McpServerState copyWith({
    bool? enabled,
    bool? running,
    int? port,
    bool? authEnabled,
    String? Function()? authToken,
    bool? bindAll,
    int? connectionCount,
    List<McpActivityEntry>? activityLog,
    bool? tunnelRunning,
    bool? tunnelStarting,
    String? Function()? tunnelUrl,
    bool? cloudflaredAvailable,
  }) {
    return McpServerState(
      enabled: enabled ?? this.enabled,
      running: running ?? this.running,
      port: port ?? this.port,
      authEnabled: authEnabled ?? this.authEnabled,
      authToken: authToken != null ? authToken() : this.authToken,
      bindAll: bindAll ?? this.bindAll,
      connectionCount: connectionCount ?? this.connectionCount,
      activityLog: activityLog ?? this.activityLog,
      tunnelRunning: tunnelRunning ?? this.tunnelRunning,
      tunnelStarting: tunnelStarting ?? this.tunnelStarting,
      tunnelUrl: tunnelUrl != null ? tunnelUrl() : this.tunnelUrl,
      cloudflaredAvailable: cloudflaredAvailable ?? this.cloudflaredAvailable,
    );
  }

  /// Returns tunnel URL when tunnel is active, localhost otherwise.
  String get httpUrl {
    if (tunnelRunning && tunnelUrl != null) return '${tunnelUrl!}/mcp';
    return 'http://localhost:$port/mcp';
  }

  String claudeCodeConfig() {
    final config = <String, dynamic>{
      'type': 'url',
      'url': httpUrl,
    };
    if (authEnabled && authToken != null) {
      config['headers'] = {'Authorization': 'Bearer $authToken'};
    }
    final encoder = const JsonEncoder.withIndent('  ');
    final wrapper = {'dispatch': config};
    return encoder.convert(wrapper);
  }
}

class McpServerNotifier extends Notifier<McpServerState> {
  McpServer? _server;
  McpNotificationManager? _notificationManager;
  Process? _tunnelProcess;
  bool _disposed = false;

  @override
  McpServerState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _tunnelProcess?.kill();
      _tunnelProcess = null;
      stopServer();
    });
    // Load settings from database at startup
    _loadSettings();
    return const McpServerState();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(databaseProvider);
    final enabled = await db.settingsDao.getValue('mcp_enabled');
    final port = await db.settingsDao.getValue('mcp_port');
    final authEnabled = await db.settingsDao.getValue('mcp_auth_enabled');
    final authToken = await db.settingsDao.getValue('mcp_auth_token');
    final bindAll = await db.settingsDao.getValue('mcp_bind_all');

    // Guard against disposal during async gap
    if (_disposed) return;

    state = state.copyWith(
      enabled: enabled == 'true',
      port: port != null ? (int.tryParse(port) ?? 3900) : 3900,
      authEnabled: authEnabled == 'true',
      authToken: () => authToken,
      bindAll: bindAll == 'true',
    );

    // Auto-start if enabled
    if (state.enabled) {
      await startServer();
    }
  }

  Future<void> _saveSettings() async {
    final db = ref.read(databaseProvider);
    await db.settingsDao.setValue('mcp_enabled', state.enabled.toString());
    await db.settingsDao.setValue('mcp_port', state.port.toString());
    await db.settingsDao.setValue('mcp_auth_enabled', state.authEnabled.toString());
    if (state.authToken != null) {
      await db.settingsDao.setValue('mcp_auth_token', state.authToken!);
    }
    await db.settingsDao.setValue('mcp_bind_all', state.bindAll.toString());
  }

  Future<void> startServer() async {
    if (_server != null) return;

    _server = McpServer(ref);
    final actualPort = await _server!.start(
      port: state.port,
      authToken: state.authEnabled ? state.authToken : null,
      bindAll: state.bindAll,
    );

    _notificationManager = McpNotificationManager(ref, _server!);
    _notificationManager!.startListening();

    state = state.copyWith(
      running: true,
      port: actualPort,
    );
  }

  Future<void> stopServer() async {
    // Stop tunnel first if running
    if (state.tunnelRunning) {
      await stopTunnel();
    }
    _notificationManager?.stopListening();
    _notificationManager = null;
    await _server?.stop();
    _server = null;
    state = state.copyWith(running: false, connectionCount: 0);
  }

  Future<void> toggle() async {
    if (state.running) {
      await stopServer();
      state = state.copyWith(enabled: false);
    } else {
      state = state.copyWith(enabled: true);
      await startServer();
    }
    await _saveSettings();
  }

  Future<void> setPort(int port) async {
    state = state.copyWith(port: port);
    if (state.running) {
      await stopServer();
      await startServer();
    }
    await _saveSettings();
  }

  Future<void> setAuthEnabled(bool enabled) async {
    if (enabled && state.authToken == null) {
      state = state.copyWith(
        authEnabled: true,
        authToken: () => McpServer.generateToken(),
      );
    } else {
      state = state.copyWith(authEnabled: enabled);
    }
    if (state.running) {
      await stopServer();
      await startServer();
    }
    await _saveSettings();
  }

  Future<void> regenerateToken() async {
    state = state.copyWith(authToken: () => McpServer.generateToken());
    if (state.running) {
      await stopServer();
      await startServer();
    }
    await _saveSettings();
  }

  Future<void> setBindAll(bool bindAll) async {
    state = state.copyWith(bindAll: bindAll);
    if (state.running) {
      await stopServer();
      await startServer();
    }
    await _saveSettings();
  }

  /// Check if cloudflared is available on the system.
  Future<void> checkCloudflared() async {
    try {
      final result = await Process.run('which', ['cloudflared']);
      state = state.copyWith(cloudflaredAvailable: result.exitCode == 0);
    } catch (_) {
      state = state.copyWith(cloudflaredAvailable: false);
    }
  }

  /// Start a cloudflare tunnel to expose the MCP server publicly.
  Future<void> startTunnel() async {
    if (_tunnelProcess != null || !state.running) return;

    state = state.copyWith(tunnelStarting: true);

    try {
      _tunnelProcess = await Process.start(
        'cloudflared',
        ['tunnel', '--url', 'http://localhost:${state.port}'],
      );

      // cloudflared outputs the URL to stderr
      final urlPattern = RegExp(r'https://[a-z0-9-]+\.trycloudflare\.com');

      _tunnelProcess!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) {
        final match = urlPattern.firstMatch(data);
        if (match != null && !_disposed) {
          state = state.copyWith(
            tunnelRunning: true,
            tunnelStarting: false,
            tunnelUrl: () => match.group(0),
          );
        }
      });

      // Handle tunnel process exit
      _tunnelProcess!.exitCode.then((_) {
        if (!_disposed) {
          _tunnelProcess = null;
          state = state.copyWith(
            tunnelRunning: false,
            tunnelStarting: false,
            tunnelUrl: () => null,
          );
        }
      });

      // Timeout: if no URL after 15 seconds, give up
      Future.delayed(const Duration(seconds: 15), () {
        if (!_disposed && state.tunnelStarting) {
          stopTunnel();
        }
      });
    } catch (_) {
      state = state.copyWith(tunnelStarting: false);
    }
  }

  /// Stop the cloudflare tunnel.
  Future<void> stopTunnel() async {
    _tunnelProcess?.kill();
    _tunnelProcess = null;
    state = state.copyWith(
      tunnelRunning: false,
      tunnelStarting: false,
      tunnelUrl: () => null,
    );
  }

  /// Refresh connection count and activity log from the server.
  void refreshStatus() {
    if (_server == null) return;
    state = state.copyWith(
      connectionCount: _server!.connectionCount,
      activityLog: List.of(_server!.activityLog),
    );
  }
}

final mcpServerProvider =
    NotifierProvider<McpServerNotifier, McpServerState>(McpServerNotifier.new);
