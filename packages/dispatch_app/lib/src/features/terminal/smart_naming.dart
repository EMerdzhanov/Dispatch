/// Detects a meaningful terminal name from recent output.
///
/// Returns a human-friendly label like "Dev Server" or "Tests",
/// or null if no pattern matches.
String? detectTerminalName(String recentOutput) {
  final lower = recentOutput.toLowerCase();

  // Order matters — more specific patterns first.
  if (lower.contains('flutter run') || lower.contains('running on')) {
    return 'Flutter Dev';
  }
  if (lower.contains('npm start') ||
      lower.contains('npm run dev') ||
      lower.contains('next dev') ||
      lower.contains('vite')) {
    return 'Dev Server';
  }
  if (lower.contains('flutter test') ||
      lower.contains('npm test') ||
      lower.contains('vitest') ||
      lower.contains('jest') ||
      lower.contains('pytest')) {
    return 'Tests';
  }
  if (lower.contains('flutter build') ||
      lower.contains('npm run build') ||
      lower.contains('webpack') ||
      lower.contains('cargo build')) {
    return 'Build';
  }
  if (lower.contains('git log') ||
      lower.contains('git diff') ||
      lower.contains('git status')) {
    return 'Git';
  }
  if (lower.contains('docker-compose') || lower.contains('docker')) {
    return 'Docker';
  }
  if (lower.contains('ssh ')) {
    return 'SSH';
  }
  if (lower.contains('python ') ||
      lower.contains('node ') ||
      lower.contains('dart run')) {
    return 'Script';
  }
  if (lower.contains('claude')) {
    return 'Claude Code';
  }

  return null;
}
