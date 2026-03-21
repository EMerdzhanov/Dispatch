enum TerminalStatus { active, running, exited }

class TerminalEntry {
  final String id;
  final String? label;
  final String? presetName;
  final String command;
  final String cwd;
  final TerminalStatus status;
  final int? exitCode;
  final int? pid;

  const TerminalEntry({
    required this.id, this.label, this.presetName, required this.command,
    required this.cwd, required this.status, this.exitCode, this.pid,
  });

  TerminalEntry copyWith({String? label, TerminalStatus? status, int? exitCode, int? pid}) {
    return TerminalEntry(
      id: id, label: label ?? this.label, presetName: presetName,
      command: command, cwd: cwd,
      status: status ?? this.status, exitCode: exitCode ?? this.exitCode,
      pid: pid ?? this.pid,
    );
  }
}
