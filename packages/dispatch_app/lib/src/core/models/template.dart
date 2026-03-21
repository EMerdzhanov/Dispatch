import 'split_node.dart';

class Template {
  final String name;
  final String cwd;
  final SplitNode? layout;

  const Template({required this.name, required this.cwd, this.layout});
}
