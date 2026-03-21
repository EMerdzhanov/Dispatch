import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Holds masterFd and pid after a successful PTY spawn.
class PtySpawnResult {
  final int masterFd;
  final int pid;

  const PtySpawnResult({required this.masterFd, required this.pid});

  @override
  String toString() => 'PtySpawnResult(masterFd: $masterFd, pid: $pid)';
}

/// Holds pid and status from waitpid.
class WaitResult {
  final int pid;
  final int status;

  const WaitResult({required this.pid, required this.status});

  @override
  String toString() => 'WaitResult(pid: $pid, status: $status)';
}

// ---------------------------------------------------------------------------
// Native typedefs
// ---------------------------------------------------------------------------

// struct winsize { unsigned short ws_row, ws_col, ws_xpixel, ws_ypixel; }
final class Winsize extends Struct {
  @Uint16()
  external int wsRow;

  @Uint16()
  external int wsCol;

  @Uint16()
  external int wsXpixel;

  @Uint16()
  external int wsYpixel;
}

// int forkpty(int *amaster, char *name, void *termp, struct winsize *winp);
typedef ForkptyNative = Int32 Function(
  Pointer<Int32> amaster,
  Pointer<Utf8> name,
  Pointer<Void> termp,
  Pointer<Winsize> winp,
);
typedef ForkptyDart = int Function(
  Pointer<Int32> amaster,
  Pointer<Utf8> name,
  Pointer<Void> termp,
  Pointer<Winsize> winp,
);

// ssize_t read(int fd, void *buf, size_t count);
typedef ReadNative = IntPtr Function(Int32 fd, Pointer<Uint8> buf, IntPtr count);
typedef ReadDart = int Function(int fd, Pointer<Uint8> buf, int count);

// ssize_t write(int fd, const void *buf, size_t count);
typedef WriteNative = IntPtr Function(
  Int32 fd,
  Pointer<Uint8> buf,
  IntPtr count,
);
typedef WriteDart = int Function(int fd, Pointer<Uint8> buf, int count);

// int close(int fd);
typedef CloseNative = Int32 Function(Int32 fd);
typedef CloseDart = int Function(int fd);

// int kill(pid_t pid, int sig);
typedef KillNative = Int32 Function(Int32 pid, Int32 sig);
typedef KillDart = int Function(int pid, int sig);

// int ioctl(int fd, unsigned long request, ...);
// We bind specifically for the TIOCSWINSZ case: ioctl(fd, req, &winsize)
typedef IoctlWinsizeNative = Int32 Function(
  Int32 fd,
  Uint64 request,
  Pointer<Winsize> winp,
);
typedef IoctlWinsizeDart = int Function(
  int fd,
  int request,
  Pointer<Winsize> winp,
);

// pid_t waitpid(pid_t pid, int *status, int options);
typedef WaitpidNative = Int32 Function(
  Int32 pid,
  Pointer<Int32> status,
  Int32 options,
);
typedef WaitpidDart = int Function(int pid, Pointer<Int32> status, int options);

// int execvp(const char *file, char *const argv[]);
typedef ExecvpNative = Int32 Function(
  Pointer<Utf8> file,
  Pointer<Pointer<Utf8>> argv,
);
typedef ExecvpDart = int Function(
  Pointer<Utf8> file,
  Pointer<Pointer<Utf8>> argv,
);

// int setenv(const char *name, const char *value, int overwrite);
typedef SetenvNative = Int32 Function(
  Pointer<Utf8> name,
  Pointer<Utf8> value,
  Int32 overwrite,
);
typedef SetenvDart = int Function(
  Pointer<Utf8> name,
  Pointer<Utf8> value,
  int overwrite,
);

// int chdir(const char *path);
typedef ChdirNative = Int32 Function(Pointer<Utf8> path);
typedef ChdirDart = int Function(Pointer<Utf8> path);

// void _exit(int status);
typedef ExitNative = Void Function(Int32 status);
typedef ExitDart = void Function(int status);

// int fcntl(int fd, int cmd, ... /* int arg */);
typedef FcntlNative = Int32 Function(Int32 fd, Int32 cmd, Int32 arg);
typedef FcntlDart = int Function(int fd, int cmd, int arg);

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// TIOCSWINSZ on macOS.
const int _tiocswinsz = 0x80087467;

/// WNOHANG for waitpid.
const int _wnohang = 1;

/// fcntl commands.
const int _fGetfl = 3; // F_GETFL
const int _fSetfl = 4; // F_SETFL

/// O_NONBLOCK on macOS.
const int _oNonblock = 0x0004;

/// Read buffer size.
const int _readBufferSize = 65536;

// ---------------------------------------------------------------------------
// PtyFfi — static class
// ---------------------------------------------------------------------------

/// Low-level Dart FFI bindings to POSIX PTY functions.
///
/// macOS only. Uses `libutil.dylib` for `forkpty` and `DynamicLibrary.process()`
/// for standard libc functions.
class PtyFfi {
  PtyFfi._();

  // -- Library handles ------------------------------------------------------

  static final DynamicLibrary _libutil = DynamicLibrary.open('libutil.dylib');
  static final DynamicLibrary _libc = DynamicLibrary.process();

  // -- Resolved function pointers -------------------------------------------

  static final ForkptyDart _forkpty =
      _libutil.lookupFunction<ForkptyNative, ForkptyDart>('forkpty');

  static final ReadDart _read =
      _libc.lookupFunction<ReadNative, ReadDart>('read');

  static final WriteDart _write =
      _libc.lookupFunction<WriteNative, WriteDart>('write');

  static final CloseDart _close =
      _libc.lookupFunction<CloseNative, CloseDart>('close');

  static final KillDart _kill =
      _libc.lookupFunction<KillNative, KillDart>('kill');

  static final IoctlWinsizeDart _ioctl =
      _libc.lookupFunction<IoctlWinsizeNative, IoctlWinsizeDart>('ioctl');

  static final WaitpidDart _waitpid =
      _libc.lookupFunction<WaitpidNative, WaitpidDart>('waitpid');

  static final ExecvpDart _execvp =
      _libc.lookupFunction<ExecvpNative, ExecvpDart>('execvp');

  static final SetenvDart _setenv =
      _libc.lookupFunction<SetenvNative, SetenvDart>('setenv');

  static final ChdirDart _chdir =
      _libc.lookupFunction<ChdirNative, ChdirDart>('chdir');

  static final ExitDart _exitFn =
      _libc.lookupFunction<ExitNative, ExitDart>('_exit');

  static final FcntlDart _fcntl =
      _libc.lookupFunction<FcntlNative, FcntlDart>('fcntl');

  // -- Public API -----------------------------------------------------------

  /// Spawns a new PTY with the given executable.
  ///
  /// Returns a [PtySpawnResult] containing the master file descriptor and child
  /// process id.
  static PtySpawnResult spawn({
    required String executable,
    required List<String> args,
    required String cwd,
    required Map<String, String> env,
    required int rows,
    required int cols,
  }) {
    // Allocate winsize struct
    final winp = calloc<Winsize>();
    winp.ref.wsRow = rows;
    winp.ref.wsCol = cols;
    winp.ref.wsXpixel = 0;
    winp.ref.wsYpixel = 0;

    // Allocate master fd output
    final amasterPtr = calloc<Int32>();

    final pid = _forkpty(amasterPtr, nullptr, nullptr, winp);

    if (pid < 0) {
      calloc.free(winp);
      calloc.free(amasterPtr);
      throw StateError('forkpty() failed with return value $pid');
    }

    if (pid == 0) {
      // ---- Child process ----
      // Set environment variables
      for (final entry in env.entries) {
        final namePtr = entry.key.toNativeUtf8();
        final valuePtr = entry.value.toNativeUtf8();
        _setenv(namePtr, valuePtr, 1);
        // Don't free in child — we're about to exec anyway.
      }

      // Change working directory
      final cwdPtr = cwd.toNativeUtf8();
      _chdir(cwdPtr);

      // Build argv: [executable, ...args, null]
      final allArgs = [executable, ...args];
      final argvPtr = calloc<Pointer<Utf8>>(allArgs.length + 1);
      for (var i = 0; i < allArgs.length; i++) {
        argvPtr[i] = allArgs[i].toNativeUtf8();
      }
      argvPtr[allArgs.length] = nullptr;

      final executablePtr = executable.toNativeUtf8();
      _execvp(executablePtr, argvPtr);

      // If execvp returns, it failed — use _exit to avoid Dart finalizers
      _exitFn(1);
    }

    // ---- Parent process ----
    final masterFd = amasterPtr.value;
    calloc.free(winp);
    calloc.free(amasterPtr);

    // Set the master fd to non-blocking so reads don't block
    final flags = _fcntl(masterFd, _fGetfl, 0);
    _fcntl(masterFd, _fSetfl, flags | _oNonblock);

    return PtySpawnResult(masterFd: masterFd, pid: pid);
  }

  /// Reads a string from the PTY. Returns `null` if no data is available.
  static String? read(int fd) {
    final bytes = readBytes(fd);
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Reads raw bytes from the PTY. Returns `null` if no data is available.
  static Uint8List? readBytes(int fd) {
    final buf = calloc<Uint8>(_readBufferSize);
    try {
      final bytesRead = _read(fd, buf, _readBufferSize);
      if (bytesRead <= 0) {
        return null;
      }
      // Copy out of native memory
      final result = Uint8List(bytesRead);
      for (var i = 0; i < bytesRead; i++) {
        result[i] = buf[i];
      }
      return result;
    } finally {
      calloc.free(buf);
    }
  }

  /// Writes a string to the PTY.
  static void write(int fd, String data) {
    writeBytes(fd, Uint8List.fromList(utf8.encode(data)));
  }

  /// Writes raw bytes to the PTY.
  static void writeBytes(int fd, Uint8List bytes) {
    final buf = calloc<Uint8>(bytes.length);
    try {
      for (var i = 0; i < bytes.length; i++) {
        buf[i] = bytes[i];
      }
      var written = 0;
      while (written < bytes.length) {
        final n = _write(fd, buf + written, bytes.length - written);
        if (n < 0) {
          throw StateError('write() failed');
        }
        written += n;
      }
    } finally {
      calloc.free(buf);
    }
  }

  /// Resizes the PTY window.
  static void resize(int fd, {required int rows, required int cols}) {
    final winp = calloc<Winsize>();
    try {
      winp.ref.wsRow = rows;
      winp.ref.wsCol = cols;
      winp.ref.wsXpixel = 0;
      winp.ref.wsYpixel = 0;
      final ret = _ioctl(fd, _tiocswinsz, winp);
      if (ret < 0) {
        throw StateError('ioctl(TIOCSWINSZ) failed with return value $ret');
      }
    } finally {
      calloc.free(winp);
    }
  }

  /// Sends a signal to a process.
  static void kill(int pid, int signal) {
    _kill(pid, signal);
  }

  /// Closes a file descriptor.
  static void close(int fd) {
    _close(fd);
  }

  /// Waits for a child process to change state.
  ///
  /// If [noHang] is true, returns `null` immediately if no child has exited.
  /// Otherwise blocks until the child exits.
  static WaitResult? waitpid(int pid, {bool noHang = false}) {
    final statusPtr = calloc<Int32>();
    try {
      final options = noHang ? _wnohang : 0;
      final result = _waitpid(pid, statusPtr, options);
      if (result <= 0) {
        // 0 means no child exited yet (WNOHANG), -1 means error
        return null;
      }
      return WaitResult(pid: result, status: statusPtr.value);
    } finally {
      calloc.free(statusPtr);
    }
  }
}
