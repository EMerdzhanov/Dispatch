// packages/dispatch_terminal/test/vt_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_terminal/src/vt_parser.dart';

void main() {
  group('VtParser', () {
    late VtParser parser;
    late List<VtAction> actions;

    setUp(() {
      actions = [];
      parser = VtParser(onAction: actions.add);
    });

    test('printable ASCII emits Print actions', () {
      parser.feed('Hello'.codeUnits);
      expect(actions.length, 5);
      expect(actions[0], isA<PrintAction>());
      expect((actions[0] as PrintAction).codepoint, 0x48); // H
    });

    test('newline emits Linefeed', () {
      parser.feed([0x0A]); // \n
      expect(actions.length, 1);
      expect(actions[0], isA<LinefeedAction>());
    });

    test('carriage return emits CarriageReturn', () {
      parser.feed([0x0D]); // \r
      expect(actions.length, 1);
      expect(actions[0], isA<CarriageReturnAction>());
    });

    test('backspace emits Backspace', () {
      parser.feed([0x08]);
      expect(actions.length, 1);
      expect(actions[0], isA<BackspaceAction>());
    });

    test('tab emits Tab', () {
      parser.feed([0x09]);
      expect(actions.length, 1);
      expect(actions[0], isA<TabAction>());
    });

    test('bell emits Bell', () {
      parser.feed([0x07]);
      expect(actions.length, 1);
      expect(actions[0], isA<BellAction>());
    });

    test('CSI cursor up: ESC[A', () {
      parser.feed([0x1B, 0x5B, 0x41]); // \e[A
      expect(actions.length, 1);
      expect(actions[0], isA<CsiAction>());
      final csi = actions[0] as CsiAction;
      expect(csi.finalByte, 0x41); // 'A'
      expect(csi.params, []);
    });

    test('CSI cursor up with count: ESC[5A', () {
      parser.feed([0x1B, 0x5B, 0x35, 0x41]); // \e[5A
      final csi = actions[0] as CsiAction;
      expect(csi.finalByte, 0x41);
      expect(csi.params, [5]);
    });

    test('CSI with multiple params: ESC[10;20H', () {
      // \e[10;20H — cursor position
      parser.feed([0x1B, 0x5B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x48]);
      final csi = actions[0] as CsiAction;
      expect(csi.finalByte, 0x48); // 'H'
      expect(csi.params, [10, 20]);
    });

    test('SGR reset: ESC[0m', () {
      parser.feed([0x1B, 0x5B, 0x30, 0x6D]); // \e[0m
      final csi = actions[0] as CsiAction;
      expect(csi.finalByte, 0x6D); // 'm'
      expect(csi.params, [0]);
    });

    test('SGR multiple: ESC[1;31m (bold + red fg)', () {
      parser.feed([0x1B, 0x5B, 0x31, 0x3B, 0x33, 0x31, 0x6D]);
      final csi = actions[0] as CsiAction;
      expect(csi.finalByte, 0x6D);
      expect(csi.params, [1, 31]);
    });

    test('OSC window title: ESC]0;title BEL', () {
      // \e]0;My Title\x07
      parser.feed([0x1B, 0x5D, 0x30, 0x3B, ...('My Title'.codeUnits), 0x07]);
      expect(actions.length, 1);
      expect(actions[0], isA<OscAction>());
      final osc = actions[0] as OscAction;
      expect(osc.params, '0;My Title');
    });

    test('OSC terminated by ST (ESC \\)', () {
      parser.feed([0x1B, 0x5D, 0x30, 0x3B, ...('Title'.codeUnits), 0x1B, 0x5C]);
      expect(actions.length, 1);
      expect(actions[0], isA<OscAction>());
    });

    test('partial sequence: split across feeds', () {
      parser.feed([0x1B]); // just ESC
      expect(actions.length, 0); // waiting for more
      parser.feed([0x5B, 0x41]); // [A
      expect(actions.length, 1);
      expect(actions[0], isA<CsiAction>());
    });

    test('UTF-8 multibyte character', () {
      // euro sign U+20AC = 0xE2 0x82 0xAC in UTF-8
      parser.feed([0xE2, 0x82, 0xAC]);
      expect(actions.length, 1);
      expect(actions[0], isA<PrintAction>());
      expect((actions[0] as PrintAction).codepoint, 0x20AC);
    });

    test('alternate screen on: ESC[?1049h', () {
      parser.feed([0x1B, 0x5B, 0x3F, 0x31, 0x30, 0x34, 0x39, 0x68]);
      expect(actions.length, 1);
      expect(actions[0], isA<DecPrivateAction>());
      final dec = actions[0] as DecPrivateAction;
      expect(dec.mode, 1049);
      expect(dec.set, true);
    });

    test('alternate screen off: ESC[?1049l', () {
      parser.feed([0x1B, 0x5B, 0x3F, 0x31, 0x30, 0x34, 0x39, 0x6C]);
      final dec = actions[0] as DecPrivateAction;
      expect(dec.mode, 1049);
      expect(dec.set, false);
    });
  });
}
