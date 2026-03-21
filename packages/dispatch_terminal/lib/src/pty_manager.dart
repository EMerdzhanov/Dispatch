import 'dart:async';
import 'dart:isolate';

import 'package:dispatch_terminal/src/pty_ffi.dart';

// ---------------------------------------------------------------------------
// Isolate message protocol — sealed classes for type safety
// ---------------------------------------------------------------------------

/// Messages sent from the main isolate to the PTY isolate.
sealed class _PtyCommand {}

class _WriteCommand extends _PtyCommand {
  final String data;
  _WriteCommand(this.data);
}

class _ResizeCommand extends _PtyCommand {
  final int cols;
  final int rows;
  _ResizeCommand(this.cols, this.rows);
}

class _DisposeCommand extends _PtyCommand {}

/// Messages sent from the PTY isolate back to the main isolate.
sealed class _PtyEvent {}

class _DataEvent extends _PtyEvent {
  final String data;
  _DataEvent(this.data);
}

class _ExitEvent extends _PtyEvent {
  final int exitCode;
  _ExitEvent(this.exitCode);
}

class _ErrorEvent extends _PtyEvent {
  final String message;
  _ErrorEvent(this.message);
}

/// The ready event sent once the isolate has spawned the PTY.
class _ReadyEvent extends _PtyEvent {
  final SendPort commandPort;
  _ReadyEvent(this.commandPort);
}

// ---------------------------------------------------------------------------
// Init message passed to the isolate entry point
// ---------------------------------------------------------------------------

class _IsolateInit {
  final SendPort eventPort;
  final String executable;
  final List<String> args;
  final String cwd;
  final Map<String, String> env;
  final int rows;
  final int cols;
  final String? command;

  _IsolateInit({
    required this.eventPort,
    required this.executable,
    required this.args,
    required this.cwd,
    required this.env,
    required this.rows,
    required this.cols,
    this.command,
  });
}

// ---------------------------------------------------------------------------
// Isolate entry point
// ---------------------------------------------------------------------------

void _isolateEntry(_IsolateInit init) {
  final commandPort = ReceivePort();
  late final PtySpawnResult pty;

  try {
    pty = PtyFfi.spawn(
      executable: init.executable,
      args: init.args,
      cwd: init.cwd,
      env: init.env,
      rows: init.rows,
      cols: init.cols,
    );
  } catch (e) {
    init.eventPort.send(_ErrorEvent('Failed to spawn PTY: $e'));
    commandPort.close();
    return;
  }

  // Notify main isolate that we're ready, providing our command port.
  init.eventPort.send(_ReadyEvent(commandPort.sendPort));

  // If a command was specified, write it immediately. The shell should already
  // be running since forkpty+execvp happened synchronously above.
  if (init.command != null) {
    try {
      PtyFfi.write(pty.masterFd, '${init.command}\n');
    } catch (_) {
      // Shell may have already exited — ignore.
    }
  }

  var disposed = false;

  // Listen for commands from the main isolate.
  commandPort.listen((message) {
    if (disposed) return;
    if (message is _WriteCommand) {
      try {
        PtyFfi.write(pty.masterFd, message.data);
      } catch (_) {
        // fd may be closed if process exited.
      }
    } else if (message is _ResizeCommand) {
      try {
        PtyFfi.resize(pty.masterFd, rows: message.rows, cols: message.cols);
      } catch (_) {
        // Ignore resize errors on dead PTY.
      }
    } else if (message is _DisposeCommand) {
      disposed = true;
      _cleanup(pty, commandPort);
    }
  });

  // Read loop — poll for data and child exit at ~10ms intervals.
  Timer.periodic(const Duration(milliseconds: 10), (timer) {
    if (disposed) {
      timer.cancel();
      return;
    }

    // Read available data.
    try {
      final data = PtyFfi.read(pty.masterFd);
      if (data != null && data.isNotEmpty) {
        init.eventPort.send(_DataEvent(data));
      }
    } catch (_) {
      // read may fail after fd is closed — that's fine.
    }

    // Check if child has exited.
    try {
      final result = PtyFfi.waitpid(pty.pid, noHang: true);
      if (result != null) {
        // Extract exit code from status using WEXITSTATUS macro:
        // (status >> 8) & 0xFF on macOS/Linux.
        final exitCode = (result.status >> 8) & 0xFF;
        init.eventPort.send(_ExitEvent(exitCode));
        disposed = true;
        timer.cancel();
        _cleanup(pty, commandPort);
      }
    } catch (_) {
      // waitpid may fail if already reaped.
    }
  });
}

void _cleanup(PtySpawnResult pty, ReceivePort commandPort) {
  try {
    PtyFfi.kill(pty.pid, 15); // SIGTERM
  } catch (_) {}
  try {
    PtyFfi.close(pty.masterFd);
  } catch (_) {}
  commandPort.close();
}

// ---------------------------------------------------------------------------
// PtySession
// ---------------------------------------------------------------------------

/// Represents a single PTY session running in its own isolate.
class PtySession {
  /// Unique identifier for this session.
  final String id;

  /// Broadcast stream of PTY output data.
  final Stream<String> dataStream;

  /// Completes when the child process exits, with the exit code.
  final Future<int> exitCode;

  final SendPort _commandPort;
  final Isolate _isolate;
  final ReceivePort _eventPort;
  final void Function(String id) _onDispose;
  bool _disposed = false;

  PtySession._({
    required this.id,
    required this.dataStream,
    required this.exitCode,
    required SendPort commandPort,
    required Isolate isolate,
    required ReceivePort eventPort,
    required void Function(String id) onDispose,
  })  : _commandPort = commandPort,
        _isolate = isolate,
        _eventPort = eventPort,
        _onDispose = onDispose;

  /// Send input to the PTY.
  void write(String data) {
    if (_disposed) return;
    _commandPort.send(_WriteCommand(data));
  }

  /// Resize the PTY window.
  void resize(int cols, int rows) {
    if (_disposed) return;
    _commandPort.send(_ResizeCommand(cols, rows));
  }

  /// Kill the child process and clean up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _commandPort.send(_DisposeCommand());
    // Give the isolate a moment to clean up, then kill it.
    Future.delayed(const Duration(milliseconds: 100), () {
      _eventPort.close();
      _isolate.kill(priority: Isolate.beforeNextEvent);
    });
    _onDispose(id);
  }
}

// ---------------------------------------------------------------------------
// PtyManager
// ---------------------------------------------------------------------------

/// Manages PTY sessions, each running in its own Dart Isolate.
class PtyManager {
  final Map<String, PtySession> _sessions = {};
  int _nextId = 0;

  /// Number of active sessions.
  int get sessionCount => _sessions.length;

  /// Spawns a new PTY session in a dedicated isolate.
  ///
  /// The [executable] is the shell or program to run (e.g., `/bin/zsh`).
  /// Optional [args] are passed to the executable.
  /// [cwd] sets the working directory for the shell.
  /// [env] sets environment variables (defaults to TERM=xterm-256color).
  /// [cols] and [rows] set the initial terminal size.
  /// [command] is an optional command to type after the shell starts.
  Future<PtySession> spawn({
    required String executable,
    List<String> args = const [],
    required String cwd,
    Map<String, String> env = const {},
    required int cols,
    required int rows,
    String? command,
  }) async {
    final sessionId = 'pty-${_nextId++}';
    final eventPort = ReceivePort();

    // Merge default env with user env.
    final mergedEnv = <String, String>{
      'TERM': 'xterm-256color',
      ...env,
    };

    final init = _IsolateInit(
      eventPort: eventPort.sendPort,
      executable: executable,
      args: args,
      cwd: cwd,
      env: mergedEnv,
      rows: rows,
      cols: cols,
      command: command,
    );

    final isolate = await Isolate.spawn(_isolateEntry, init);

    // Wait for the ready event from the isolate.
    final readyCompleter = Completer<SendPort>();
    final exitCompleter = Completer<int>();
    final dataController = StreamController<String>.broadcast();

    eventPort.listen((message) {
      if (message is _ReadyEvent) {
        if (!readyCompleter.isCompleted) {
          readyCompleter.complete(message.commandPort);
        }
      } else if (message is _DataEvent) {
        if (!dataController.isClosed) {
          dataController.add(message.data);
        }
      } else if (message is _ExitEvent) {
        if (!exitCompleter.isCompleted) {
          exitCompleter.complete(message.exitCode);
        }
        // Close the data stream after a brief delay to ensure all data is
        // flushed.
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!dataController.isClosed) {
            dataController.close();
          }
        });
      } else if (message is _ErrorEvent) {
        if (!readyCompleter.isCompleted) {
          readyCompleter.completeError(StateError(message.message));
        }
      }
    });

    final commandPort = await readyCompleter.future;

    final session = PtySession._(
      id: sessionId,
      dataStream: dataController.stream,
      exitCode: exitCompleter.future,
      commandPort: commandPort,
      isolate: isolate,
      eventPort: eventPort,
      onDispose: (id) {
        _sessions.remove(id);
      },
    );

    _sessions[sessionId] = session;
    return session;
  }

  /// Disposes all active sessions.
  void disposeAll() {
    // Copy keys to avoid concurrent modification.
    final ids = _sessions.keys.toList();
    for (final id in ids) {
      _sessions[id]?.dispose();
    }
  }
}
