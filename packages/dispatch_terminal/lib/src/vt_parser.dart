// packages/dispatch_terminal/lib/src/vt_parser.dart

/// Actions emitted by the VT parser.
sealed class VtAction {}

class PrintAction extends VtAction {
  final int codepoint;
  PrintAction(this.codepoint);
}

class LinefeedAction extends VtAction {}
class CarriageReturnAction extends VtAction {}
class BackspaceAction extends VtAction {}
class TabAction extends VtAction {}
class BellAction extends VtAction {}

class CsiAction extends VtAction {
  final int finalByte;
  final List<int> params;
  CsiAction(this.finalByte, this.params);
}

class OscAction extends VtAction {
  final String params;
  OscAction(this.params);
}

class DecPrivateAction extends VtAction {
  final int mode;
  final bool set;
  DecPrivateAction(this.mode, this.set);
}

class EscAction extends VtAction {
  final int finalByte;
  EscAction(this.finalByte);
}

enum _State {
  ground,
  escape,
  csiEntry,
  csiParam,
  oscString,
  utf8,
}

/// VT100/xterm escape sequence parser.
///
/// Feed bytes in, get structured [VtAction]s out via the [onAction] callback.
class VtParser {
  final void Function(VtAction action) onAction;

  _State _state = _State.ground;
  final List<int> _paramBuffer = [];
  final List<int> _oscBuffer = [];
  bool _csiPrivate = false;

  // UTF-8 decoding state
  int _utf8Codepoint = 0;
  int _utf8Remaining = 0;

  VtParser({required this.onAction});

  void feed(List<int> bytes) {
    for (final byte in bytes) {
      _process(byte);
    }
  }

  void _process(int byte) {
    // Handle UTF-8 continuation bytes in ground state
    if (_state == _State.utf8) {
      if ((byte & 0xC0) == 0x80) {
        _utf8Codepoint = (_utf8Codepoint << 6) | (byte & 0x3F);
        _utf8Remaining--;
        if (_utf8Remaining == 0) {
          onAction(PrintAction(_utf8Codepoint));
          _state = _State.ground;
        }
        return;
      } else {
        // Invalid continuation — reset and reprocess
        _state = _State.ground;
      }
    }

    switch (_state) {
      case _State.ground:
        _processGround(byte);
      case _State.escape:
        _processEscape(byte);
      case _State.csiEntry:
      case _State.csiParam:
        _processCsi(byte);
      case _State.oscString:
        _processOsc(byte);
      case _State.utf8:
        break; // handled above
    }
  }

  void _processGround(int byte) {
    if (byte == 0x1B) {
      _state = _State.escape;
    } else if (byte == 0x0A || byte == 0x0B || byte == 0x0C) {
      onAction(LinefeedAction());
    } else if (byte == 0x0D) {
      onAction(CarriageReturnAction());
    } else if (byte == 0x08) {
      onAction(BackspaceAction());
    } else if (byte == 0x09) {
      onAction(TabAction());
    } else if (byte == 0x07) {
      onAction(BellAction());
    } else if (byte >= 0x20 && byte < 0x7F) {
      onAction(PrintAction(byte));
    } else if ((byte & 0xE0) == 0xC0) {
      // 2-byte UTF-8
      _utf8Codepoint = byte & 0x1F;
      _utf8Remaining = 1;
      _state = _State.utf8;
    } else if ((byte & 0xF0) == 0xE0) {
      // 3-byte UTF-8
      _utf8Codepoint = byte & 0x0F;
      _utf8Remaining = 2;
      _state = _State.utf8;
    } else if ((byte & 0xF8) == 0xF0) {
      // 4-byte UTF-8
      _utf8Codepoint = byte & 0x07;
      _utf8Remaining = 3;
      _state = _State.utf8;
    }
    // Other C0 controls silently ignored
  }

  void _processEscape(int byte) {
    if (byte == 0x5B) {
      // ESC [ → CSI
      _state = _State.csiEntry;
      _paramBuffer.clear();
      _csiPrivate = false;
    } else if (byte == 0x5D) {
      // ESC ] → OSC
      _state = _State.oscString;
      _oscBuffer.clear();
    } else if (byte == 0x5C) {
      // ESC \ → ST (string terminator) — no-op if not in string
      _state = _State.ground;
    } else if (byte >= 0x40 && byte < 0x7F) {
      // ESC + final byte
      onAction(EscAction(byte));
      _state = _State.ground;
    } else {
      // Unknown — return to ground
      _state = _State.ground;
    }
  }

  void _processCsi(int byte) {
    if (byte == 0x3F && _state == _State.csiEntry) {
      // '?' private mode indicator
      _csiPrivate = true;
      _state = _State.csiParam;
    } else if (byte >= 0x30 && byte <= 0x39) {
      // Digit — accumulate param
      _paramBuffer.add(byte);
      _state = _State.csiParam;
    } else if (byte == 0x3B) {
      // ';' — param separator
      _paramBuffer.add(byte);
      _state = _State.csiParam;
    } else if (byte >= 0x40 && byte <= 0x7E) {
      // Final byte
      final params = _parseParams();

      if (_csiPrivate) {
        final mode = params.isNotEmpty ? params[0] : 0;
        final set = byte == 0x68; // 'h' = set, 'l' = reset
        onAction(DecPrivateAction(mode, set));
      } else {
        onAction(CsiAction(byte, params));
      }
      _state = _State.ground;
    } else {
      // Intermediate byte or unknown — stay in CSI
      _state = _State.csiParam;
    }
  }

  List<int> _parseParams() {
    if (_paramBuffer.isEmpty) return [];
    final str = String.fromCharCodes(_paramBuffer);
    return str.split(';').map((s) => int.tryParse(s) ?? 0).toList();
  }

  void _processOsc(int byte) {
    if (byte == 0x07) {
      // BEL terminates OSC
      onAction(OscAction(String.fromCharCodes(_oscBuffer)));
      _state = _State.ground;
    } else if (byte == 0x1B) {
      // Might be ESC \ (ST)
      onAction(OscAction(String.fromCharCodes(_oscBuffer)));
      _state = _State.escape;
    } else {
      _oscBuffer.add(byte);
    }
  }
}
