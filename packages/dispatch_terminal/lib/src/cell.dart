/// A single character cell in the terminal screen buffer.
class Cell {
  static const int defaultFg = 0xFFCCCCCC; // light gray
  static const int defaultBg = 0xFF0A0A1A; // dark background

  final int char;
  final int fg;
  final int bg;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool inverse;
  final bool strikethrough;
  final bool blink;

  const Cell({
    this.char = 0x20, // space
    this.fg = defaultFg,
    this.bg = defaultBg,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.inverse = false,
    this.strikethrough = false,
    this.blink = false,
  });

  Cell reset() => const Cell();

  Cell copyWith({
    int? char,
    int? fg,
    int? bg,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? inverse,
    bool? strikethrough,
    bool? blink,
  }) {
    return Cell(
      char: char ?? this.char,
      fg: fg ?? this.fg,
      bg: bg ?? this.bg,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      inverse: inverse ?? this.inverse,
      strikethrough: strikethrough ?? this.strikethrough,
      blink: blink ?? this.blink,
    );
  }
}
