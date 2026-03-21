class Preset {
  final String name;
  final String command;
  final String color;
  final String icon;
  final Map<String, String>? env;

  const Preset({required this.name, required this.command, required this.color, required this.icon, this.env});

  static const defaults = [
    Preset(name: 'Claude Code', command: 'claude', color: '#0f3460', icon: 'brain'),
    Preset(name: 'Resume Session', command: 'claude --resume', color: '#e94560', icon: 'rotate-ccw'),
    Preset(name: 'Skip Permissions', command: 'claude --dangerously-skip-permissions', color: '#f5a623', icon: 'zap'),
    Preset(name: 'Shell', command: '\$SHELL', color: '#888888', icon: 'terminal'),
  ];
}
