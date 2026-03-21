enum SplitDirection { horizontal, vertical }

sealed class SplitNode {
  const SplitNode();

  /// Returns the terminal ID if this node is a [SplitLeaf], otherwise null.
  String? get terminalId => null;

  static SplitNode buildEqualSplit(List<String> terminalIds, SplitDirection direction) {
    if (terminalIds.length == 1) return SplitLeaf(terminalId: terminalIds[0]);
    if (terminalIds.length == 2) {
      return SplitBranch(
        direction: direction, ratio: 0.5,
        children: (SplitLeaf(terminalId: terminalIds[0]), SplitLeaf(terminalId: terminalIds[1])),
      );
    }
    final mid = (terminalIds.length + 1) ~/ 2;
    return SplitBranch(
      direction: direction, ratio: mid / terminalIds.length,
      children: (
        buildEqualSplit(terminalIds.sublist(0, mid), direction),
        buildEqualSplit(terminalIds.sublist(mid), direction),
      ),
    );
  }
}

class SplitLeaf extends SplitNode {
  @override
  final String terminalId;
  const SplitLeaf({required this.terminalId});
}

class SplitBranch extends SplitNode {
  final SplitDirection direction;
  final double ratio;
  final (SplitNode, SplitNode) children;

  const SplitBranch({required this.direction, required this.ratio, required this.children});

  SplitBranch copyWith({double? ratio, (SplitNode, SplitNode)? children}) {
    return SplitBranch(direction: direction, ratio: ratio ?? this.ratio, children: children ?? this.children);
  }
}
