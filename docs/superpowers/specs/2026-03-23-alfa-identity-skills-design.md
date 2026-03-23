# Alfa Identity & Skills System — Design Spec

## Overview

Elevates Alfa from a basic chat-with-tools agent to a full orchestration engine with structured identity, persistent memory, orchestration skills, loadable playbooks, and self-improvement through suggest-then-save learning.

## Identity

Alfa's identity is a user-editable markdown file at `~/.config/dispatch/alfa/identity.md`. It replaces the hardcoded system prompt. Read on every interaction as the foundation of the system prompt. If missing, a default is created on first run.

The identity defines:
- **Role** — orchestrator, not coder. Delegates to terminal agents.
- **Core behaviors** — delegate, monitor, coordinate, synthesize, escalate
- **Memory discipline** — read before acting, write when it matters
- **Project awareness** — always load context before delegating
- **Delegation protocol** — objective, scope, constraints, context, success signal
- **Monitoring signals** — done, question, stuck, error, conflict
- **Coordination rules** — one agent per file, file ownership with TTLs
- **Synthesis structure** — evaluate against task spec, agent output, delta, integration
- **Escalation criteria** — ambiguous requirements, tradeoff decisions, unresolvable errors
- **Agent ground rules** — one file per agent, full briefing, verify completion
- **Error handling** — stuck agents, errors, conflicts, uncertainty, broken builds
- **Personality** — concise, direct, dry, honest, opinionated, action-first
- **Human modeling** — learns delegation style, detail tolerance, risk appetite
- **Request routing** — playbook match → plan → direct delegate → answer → clarify
- **Startup/shutdown sequences** — load/save all state files

Full identity document provided by user (see implementation plan for exact content).

## Memory System

File-based persistent memory replacing the Drift decisions table approach:

```
~/.config/dispatch/alfa/
  identity.md          — who Alfa is (system prompt foundation)
  memory.md            — long-term user preferences, patterns, observations
  log.md               — append-only decision log (max 500 entries, oldest pruned on write)
  agents.json          — live state of running agents + active plan
  playbooks/           — loadable orchestration playbooks
    code-review.md
    debug-workflow.md
    feature-build.md
    ...
  projects/
    {slugified-path}.md — per-project context (path slugified: /Users/me/app → users-me-app.md)
```

### agents.json Structure

```json
{
  "agents": {
    "term-1710000000-alfa": {
      "task": "Implement auth middleware",
      "plan_step_id": "step-1",
      "success_signal": "dart analyze passes, no errors",
      "project": "my-app",
      "status": "working",
      "files_claimed": ["src/auth.ts", "src/middleware.ts"],
      "claimed_at": "2026-03-23T01:00:00Z",
      "last_heartbeat": "2026-03-23T01:02:30Z",
      "spawned_at": "2026-03-23T01:00:00Z"
    }
  },
  "active_plans": [{
    "id": "plan-1710000000",
    "task": "Build auth system",
    "created_at": "2026-03-23T01:00:00Z",
    "steps": [
      {
        "id": "step-1",
        "description": "Create auth middleware",
        "status": "done",
        "agent": "term-1710000000-alfa"
      },
      {
        "id": "step-2",
        "description": "Add session handling",
        "status": "working",
        "agent": "term-1710000001-alfa",
        "depends_on": ["step-1"]
      },
      {
        "id": "step-3",
        "description": "Write auth tests",
        "status": "pending",
        "depends_on": ["step-1"]
      }
    ]
  }],
  "completed_plans": []
}
```

- **`active_plans`** is an array — multiple plans can run concurrently (e.g., "build auth" and "set up CI"). CoordinateSkill prevents file conflicts across plans.
- **`completed_plans`** stores finished plans for reference. Pruned after 20 entries.

- **plan_step_id** links each agent to the plan step it's executing, so SynthesizeSkill can evaluate against the original spec
- **success_signal** is the concrete verification criteria from the plan
- **depends_on** lets CoordinateSkill sequence work and parallelize where safe
- **File claims have timestamps** — claims expire after 300s without heartbeat renewal. Stale claims auto-release.
- **Concurrent write safety** — The `update_agents` tool implementation uses a mutex (Dart `Completer`-based lock) to serialize all reads and writes to `agents.json`. No parallel tool executions can corrupt the file.
- **Heartbeat source** — MonitorSkill updates heartbeats on both terminal output events AND on poll ticks (every 30s). This prevents silent-but-active agents from having claims expire.

## Request Router

Built into the identity doc. Before acting on any request, Alfa classifies:

1. **Playbook match?** → Run the matching playbook
2. **Multi-step task?** → Invoke PlanSkill, decompose, delegate step by step
3. **Single-agent task?** → Delegate directly, skip the plan
4. **Question or status check?** → Answer from memory/context, no terminals
5. **Ambiguous?** → Ask one clarifying question

Never over-engineer simple requests. Never under-engineer complex ones.

## Skills System

Two layers: hardcoded orchestration engine + loadable playbooks.

### Hardcoded Skills (Dart code)

Skills are NOT Claude-callable tools. They are internal Dart logic that runs automatically based on what Claude does with the existing tools:

- **PlanSkill** activates when Claude writes to `agents.json` `active_plan` via `update_agents`. The Dart code validates the plan structure, checks for dependency cycles, and enforces the constraint rules.
- **DelegateSkill** activates when Claude calls `spawn_terminal` + `run_command` for an Alfa-managed terminal. The Dart code auto-registers the agent in `agents.json` and runs CoordinateSkill's file ownership check.
- **MonitorSkill** runs as a background async task, watching all Alfa-spawned terminals.
- **CoordinateSkill** runs as validation logic inside `update_agents` — any file claim is checked against existing claims before being granted.
- **SynthesizeSkill** is invoked by Claude through its existing tools (`read_terminal`, `run_shell_command` for git diff, etc.). The skill's "four dimensions" are guidance in the identity doc, not a separate tool.

In short: Claude orchestrates using the existing tools. The hardcoded skills are guardrails and automation that run in Dart around those tool calls.

**`PlanSkill`** — Takes a high-level task, decomposes into ordered sub-tasks, identifies parallel vs sequential dependencies, maps file ownership requirements, produces an execution plan stored in `agents.json` `active_plan`. Runs before any multi-step delegation.

**`DelegateSkill`** — Takes a sub-task (from PlanSkill or directly), loads project context, checks `agents.json` for file ownership conflicts, composes a briefed prompt (objective/scope/constraints/context/success-signal), sends via `run_command`. Registers the agent in `agents.json`.

**`MonitorSkill`** — Event-driven primary, poll fallback. The existing `SessionRegistry.appendOutput()` is extended with an optional callback that MonitorSkill registers per-terminal. When output arrives, MonitorSkill classifies it (done, question, stuck, error, conflict) and updates heartbeat timestamps in `agents.json`. A 30s poll timer runs as fallback for missed events. MonitorSkill runs within the orchestrator's Dart code as an async background task — it does NOT trigger new Claude API calls. Instead, it updates `agents.json` state which Claude reads on its next tool call. For critical events (error, conflict), MonitorSkill emits an `AlfaChatEvent` so the UI shows an alert and the orchestrator can inject a system message on the next turn. MonitorSkill debounces AlfaChatEvent emissions — same terminal, same error classification, max one alert per 60 seconds.

**`CoordinateSkill`** — File ownership with TTLs. Every claim gets a timestamp. Claims expire after 300s without heartbeat renewal. Stale claims auto-release. Before delegation, checks for active claims. Operations: `claim_files`, `release_files`, `who_owns_file`, `cleanup_stale`. Cross-plan conflicts are treated identically to within-plan conflicts — second claim is rejected, Alfa surfaces the conflict to the human and asks which plan takes priority.

**`SynthesizeSkill`** — Structured evaluation against four dimensions:
1. **Task spec** — original plan step (from `agents.json` `plan_step_id` → `active_plan.steps`)
2. **Agent output** — terminal output (via `read_terminal`)
3. **Delta** — what changed on disk (`git diff` via `run_shell_command`)
4. **Integration check** — broken imports, type errors (run build/analyze from project context)

Output: pass/fail per dimension, issues found, suggested next actions.

### Loadable Playbooks (Markdown files)

Located at `~/.config/dispatch/alfa/playbooks/`. YAML frontmatter + steps + history.

```markdown
---
name: Code Review
description: Orchestrate a code review by delegating file analysis to a terminal agent
triggers: review, code review, check this code, audit
outputs:
  - type: summary
    format: markdown
  - type: file_changes
    format: diff
---

## Steps

1. Load project context
2. Identify files to review (ask human if unclear)
3. Spawn a terminal with Claude Code
4. Brief it: "Review these files for bugs, security issues, and code quality.
   Report findings with file:line references."
5. Monitor until complete
6. Read output, synthesize against task spec
7. Present clean summary to human
8. If human wants fixes, delegate to a new terminal

## History
<!-- Alfa appends outcomes here after each run -->
```

**Frontmatter fields:**
- `name` — display name
- `description` — what it does (included in system prompt for Claude to select)
- `triggers` — comma-separated keywords, included in the system prompt as hints for Claude (not used for programmatic matching — Claude decides)
- `outputs` — what the playbook produces (type + format), used by SynthesizeSkill
- `draft` — (optional) `true` for auto-created playbooks pending human review. When a draft playbook is triggered, Alfa prepends: `[DRAFT PLAYBOOK — not yet reviewed] Proceeding with {name}...` before executing

### Skill Selection

Claude decides. All playbook names + descriptions are listed in a `## Available Playbooks` section of the system prompt. Claude picks based on context, guided by the request router heuristic.

## Self-Improvement (Suggest-then-Save)

After any orchestration run (playbook or plan):

1. **Evaluate** — Did the playbook work as written? Were adjustments needed mid-run?
2. **Propose in chat** — "That code review playbook needed a lint step before review. Want me to update it?"
3. **On approval** — Alfa appends to the playbook's `## History` section and optionally modifies `## Steps`
4. **New playbook suggestion** — If a PlanSkill workflow succeeded and looks reusable: "I just ran a deploy workflow that worked. Want me to save it as a playbook?"
5. **On approval** — Creates new `.md` file with `draft: true` in frontmatter. Draft playbooks work but are flagged when triggered.

No autonomous writing. Every change goes through the human. Alfa always proposes.

## Tools

### New Tools

| Tool | Description |
|------|-------------|
| `load_playbook` | List available playbooks (names + descriptions) or load one by name (returns full markdown) |
| `save_playbook` | Create or update a playbook file (after human approval) |
| `update_agents` | Read/write `agents.json` — register agent, update status/heartbeat, claim/release files, cleanup stale, read/write active plan |
| `append_log` | Append entry to `log.md` with timestamp. Prunes oldest entries when file exceeds 500 entries |
| `read_memory` | Read `memory.md` |
| `update_memory` | Overwrite `memory.md` entirely. Claude manages the full content — reads first, modifies, writes back. If `memory.md` exceeds 1500 tokens, Alfa proposes a summarization pass to the human before writing new content |
| `read_project` | Read `projects/{slugified-path}.md`. Path is slugified from CWD (e.g., `/Users/me/app` → `users-me-app.md`) to avoid collisions |
| `update_project` | Overwrite `projects/{slugified-path}.md`. Claude manages full content |

### Replaced Tools

| Old Tool | Replaced By |
|----------|-------------|
| `save_decision` | `append_log` |
| `search_decisions` | `run_shell_command` with `grep` on `log.md` for keyword search, or `read_memory` for preference lookup |
| `read_project_knowledge` | `read_project` |
| `update_project_knowledge` | `update_project` |

### Unchanged Tools

`spawn_terminal`, `write_to_terminal`, `run_command`, `read_terminal`, `kill_terminal`, `list_terminals`, `create_project`, `close_project`, `list_projects`, `scan_project`, `read_file`, `list_directory`, `run_shell_command`

## System Prompt Assembly

Per-interaction, the system prompt is assembled from:

1. **Identity** — contents of `identity.md`
2. **Memory** — contents of `memory.md` (truncated to ~2000 tokens if large)
3. **Project context** — contents of `projects/{active-project}.md`
4. **Available playbooks** — list of playbook names + descriptions (from frontmatter)
5. **Agent state** — summary of `agents.json` (running agents, active plan status)
6. **Recent log** — last 10 entries from `log.md`
7. **Recent conversation** — last 20 messages from DB (existing)

Total budget: ~12000 tokens max. Identity is the largest part (~4000 tokens). Memory and project context are truncated to ~2000 tokens each if large. Playbook list, agent state, log, and conversation are compact summaries (~500 tokens each).

## Startup Sequence

On app launch (or when Alfa re-initializes):

1. Load `identity.md` (create default if missing)
2. Load `memory.md` (create empty if missing)
3. Load `projects/{active-project}.md` if an active project exists
4. Load `agents.json` — check for stale agents, cleanup expired claims
5. Load last 10 entries from `log.md`
6. Load playbook list (names + descriptions from frontmatter)
7. First message includes current state: running agents, pending tasks, what needs attention

## Shutdown Sequence

Best-effort — app crashes and force-quits will skip this. The startup sequence's stale cleanup (step 4) handles recovery. When session ends normally (app close or explicit end):

1. Update `agents.json` with final status of all terminals
2. Append session summary to `log.md`
3. Update `projects/{name}.md` if architecture changed
4. Update `memory.md` if user preferences were learned

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Identity format | User-editable markdown file | User controls who Alfa is |
| Memory system | File-based (md + json) | Human-readable, git-friendly, survives DB resets |
| Skills architecture | Hardcoded engine + loadable playbooks | Critical orchestration in Dart, extensible playbooks as markdown |
| Self-improvement | Suggest-then-save | Human stays in control, Alfa always proposes |
| Skill selection | Claude decides from list | Handles natural language intent better than keyword matching |
| Request routing | 5-level heuristic in identity | Prevents over/under-engineering responses |
| File ownership | TTL-based claims in agents.json | Prevents stale locks from crashed agents |
| Monitor approach | Event-driven + poll fallback | Catches fast failures, poll as safety net |
| Project naming | By slugified path, not hash | Human-readable project files |

## Migration from v1

On first run after upgrade:
- Existing `projects/{sha256-hash}/knowledge.md` files are migrated to `projects/{slugified-path}.md` by reading the Drift `ProjectGroups` table to map CWDs to hashes, then copying files to new paths. Old files are left in place (not deleted).
- Existing `AlfaDecisions` table entries are exported to `log.md` as initial entries.
- Existing `AlfaConversations` table continues to work (conversation history in DB is unchanged).
- The `AlfaDecisions` table is no longer written to but remains readable for reference.

## Future Extensions (Not in this version)

- Multi-model routing (pick Claude Code vs Codex vs Gemini per task type)
- Playbook marketplace (share/import playbooks)
- Agent-to-agent communication (agents can message each other through Alfa)
- Visual plan viewer in the UI (Gantt-like view of active plan steps)
