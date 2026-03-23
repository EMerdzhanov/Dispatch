# Next Task: Agent Auth Status Panel

## Overview
Add an Agent Status panel to Dispatch that shows the auth/health status of every AI coding agent installed on the machine. This solves the problem we hit in testing where Gemini was stuck on auth for 10 minutes and nobody knew.

## Where it lives
Settings gear icon → new "Agents" tab in the settings panel. Shows all known agents with status indicators.

## Agents to check

| Agent | Check command | Auth indicator |
|-------|--------------|----------------|
| Claude Code | `claude --version` | Exit code 0 = ok |
| Gemini CLI | `gemini --version` | Exit code 0 = ok |
| Codex CLI | `codex --version` or check OPENAI_API_KEY | Exit code 0 = ok |
| GitHub Copilot | `gh copilot --version` | Exit code 0 = ok |

## Status indicators
- 🟢 **Authenticated** — command ran successfully, show version
- 🟡 **Not installed** — command not found
- 🔴 **Auth required** — installed but auth failed or expired
- ⏳ **Checking...** — status check in progress

## Implementation

### 1. AgentStatusChecker service (agent_status_checker.dart)
- Run each check command via Process.run()
- Parse exit code and stdout for version
- Return AgentStatus { name, installed, authenticated, version, error }
- Cache results for 60 seconds (don't re-check on every render)
- Expose a refresh() method

### 2. AgentStatusPanel widget (agent_status_panel.dart)
- List each agent with name, status dot, version string
- "Re-check" button per agent + "Refresh All" at top
- If 🔴 Auth required — show a "Fix" button that runs the auth command in a new terminal:
  - Claude Code: opens claude.ai in browser
  - Gemini: spawns `gemini auth login` terminal
  - Codex: shows instructions to set OPENAI_API_KEY
- Auto-refresh on app focus (user may have just authed in browser)

### 3. Wire into Settings
Add "Agents" tab to the existing settings panel alongside existing tabs.

### 4. MCP tool
Add get_agent_status() tool — returns current status of all agents as JSON. Alfa uses this before spawning an agent to check it's ready. If not ready, Alfa tells the user rather than spawning a broken terminal.

## After implementing:
- dart analyze — fix all errors
- Summarize files changed
