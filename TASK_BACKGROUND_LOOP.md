# Task: Always-On Background Loop for Alfa

## Overview
Alfa currently only acts when spoken to. This implements a background loop that runs continuously, watching for things that need attention without the user having to ask. This is what makes Alfa truly autonomous.

## What the loop does

Every 30 seconds, the background loop checks:

1. **[ALFA] tasks** — scan tasks for active project for any with [ALFA] prefix that are not done. If found and not already being handled, inject into Alfa chat.

2. **Running servers** — for each terminal that looks like a dev server (contains "localhost", "port", "listening", "started"), check if it's still alive. If a server terminal has been idle >5min with no output, alert Alfa: "Dev server in {terminal} may have crashed — no output for 5 minutes."

3. **Build/test failures** — scan recent terminal output for error patterns (Error:, FAILED, exception, crash). If found in a terminal that hasn't been flagged yet, alert Alfa.

4. **Git status** — every 5 minutes, run `git status --short` in the active project cwd. If there are uncommitted changes older than 30 minutes, note it in the log (don't alert unless >2 hours).

5. **[ALFA] task completion check** — for any [ALFA] task currently being handled, check if the assigned terminal has gone idle (done). If done, mark the task complete and notify user.

## Implementation

### BackgroundLoop class (background_loop.dart)
Located at: packages/dispatch_app/lib/src/features/alfa/background_loop.dart

```dart
class BackgroundLoop {
  Timer? _timer;
  final Duration interval;
  
  BackgroundLoop({this.interval = const Duration(seconds: 30)});
  
  void start() { ... }
  void stop() { ... }
  Future<void> _tick() async { ... } // runs all checks
}
```

### Checks to implement:

**_checkAlfaTasks()** 
- Read tasks for active project via tasksDao
- Find any title starting with [ALFA] (case insensitive) where done = false
- Check agents.json to see if it's already being handled
- If not handled: call alfaProvider.notifier.injectTask(task)

**_checkServerHealth()**
- Get all running terminals from SessionRegistry
- For terminals idle > 300s (5 min) that previously had server output
- Emit AlfaChatEvent with alert message

**_checkBuildErrors()**
- For each terminal, read last 20 lines of output
- Run through error pattern matching (same as MonitorSkill but for background polling)
- Track which terminals have already been flagged (don't repeat alerts)
- Clear flag when terminal gets new output

**_checkGitStatus()**
- Run every 5th tick (every 2.5 minutes)
- Process.run('git', ['status', '--short'], workingDirectory: activeCwd)
- If output is non-empty, store in a state variable
- If changes are >2 hours old (compare with file mtimes), inject reminder into Alfa

### Wire into AlfaOrchestrator
- Create BackgroundLoop instance in AlfaOrchestrator
- Start loop when orchestrator initializes
- Stop loop when app goes to background (use WidgetsBindingObserver)
- Pause loop during active Alfa conversation to avoid interrupting mid-task

### Loop state tracking
Add to agents.json or a separate loop_state.json:
```json
{
  "handled_alfa_tasks": ["task-id-1", "task-id-2"],
  "flagged_terminals": ["term-id-1"],
  "last_git_check": "2026-03-23T02:00:00Z",
  "last_tick": "2026-03-23T02:05:00Z"
}
```

### MCP tool
Add get_loop_status() — returns current loop state: running/paused, last tick time, what was found in last tick, any active alerts.

## Important constraints
- Loop must NEVER block the UI thread — all checks are async
- Loop must NOT fire alerts for the same issue repeatedly — track what's been flagged
- Loop must PAUSE when user is actively typing in Alfa chat (don't interrupt)
- Loop must be lightweight — no expensive operations, no file reads >10KB
- Git check only runs if the project cwd has a .git folder

## After implementing:
- dart analyze — fix all errors  
- Test that the loop starts on app launch
- Summarize files created/modified
