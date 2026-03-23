# Alfa Orchestrator — Design Spec

## Overview

Alfa is a persistent AI orchestrator agent embedded inside Dispatch. It turns Dispatch from a terminal manager into an AI-native coding IDE where the human directs an intelligent agent that manages terminals running AI coding tools (Claude Code, Codex CLI, Gemini CLI).

The human talks to Alfa via a chat panel. Alfa reasons about the task, spawns terminals, delegates work to AI coding agents running in those terminals, monitors their output, makes decisions, and reports back. It has full autonomy — no confirmation gates.

## Architecture

Alfa is a plain Dart class inside `packages/dispatch_app`, instantiated with a `Ref` (same pattern as `McpServer`). It calls Claude's REST API directly via HTTP (no SDK). It has direct access to Riverpod providers for terminal and project management via the injected `Ref`.

```
┌─────────────────────────────────────────────────────────┐
│ Dispatch Flutter App                                     │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ AlfaOrchestrator (Dart class, Ref-injected)       │   │
│  │                                                   │   │
│  │  ┌─────────────┐  ┌──────────────┐              │   │
│  │  │ ClaudeClient │  │ ToolExecutor  │              │   │
│  │  │ (HTTP→API)   │  │ (runs tools)  │              │   │
│  │  └──────┬──────┘  └──────┬───────┘              │   │
│  │         │                 │                       │   │
│  │         │  agentic loop   │                       │   │
│  │         └────────┬────────┘                       │   │
│  │                  │                                │   │
│  │  ┌───────────────┴───────────────┐               │   │
│  │  │ Tools (17)                     │               │   │
│  │  │ Terminal: spawn, type, read,   │               │   │
│  │  │   kill, list                   │               │   │
│  │  │ Project: create, close, list   │               │   │
│  │  │ Knowledge: read, update, scan  │               │   │
│  │  │ Filesystem: read_file,         │               │   │
│  │  │   list_directory, run_shell    │               │   │
│  │  │ Memory: save_decision,         │               │   │
│  │  │   search_decisions             │               │   │
│  │  └───────────────────────────────┘               │   │
│  └──────────────────────┬───────────────────────────┘   │
│                         │ direct Riverpod access         │
│  ┌──────────────────────┴───────────────────────────┐   │
│  │ Existing Dispatch                                 │   │
│  │ • TerminalsProvider  • ProjectsProvider           │   │
│  │ • SessionRegistry    • TerminalMonitor            │   │
│  │ • McpServer          • Drift DB                   │   │
│  └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

Alfa sits alongside the existing MCP server — not replacing it. MCP remains for external tool access. Alfa uses direct Riverpod provider access since it runs in-process.

## Agentic Loop

Each human interaction runs this loop:

1. Build messages array: system prompt (identity + project knowledge + recent decisions) + new human message
2. Call Claude API with tools
3. If response contains `tool_use` → execute tool(s), build `tool_result`, append to messages, call API again
4. If response contains text → stream to chat panel, loop ends

Key behaviors:

- **Parallel tool execution** — Multiple `tool_use` blocks in one response execute concurrently
- **Ephemeral conversations** — Each interaction starts fresh. Context comes from project knowledge files and the decisions DB, not from growing conversation history
- **Streaming** — Text responses stream token-by-token to the chat panel
- **Per-turn timeout** — Each tool execution has a wall-clock timeout (30 seconds for `run_shell_command`, 5 seconds for state reads). If exceeded, the process is killed and an error result is returned to Claude
- **Cost guard** — Configurable max-turns limit (default: 50). Warns when approaching and summarizes progress. Prevents pathological loops where Claude repeatedly reads unchanged terminal output

## Tool Definitions

### Terminal Management
| Tool | Params | Returns | Description |
|------|--------|---------|-------------|
| `spawn_terminal` | `project_id`, `command`, `cwd`, `label?` | `terminal_id` | Spawns PTY, adds to project group |
| `write_to_terminal` | `terminal_id`, `data` | `success` | Sends raw bytes to PTY (no newline appended). For control sequences like Ctrl-C |
| `run_command` | `terminal_id`, `command` | `success` | Sends command text + carriage return to PTY. For typing prompts |
| `read_terminal` | `terminal_id`, `lines?` | `output` (raw text) | Last N lines from output buffer (default 100). Output includes ANSI codes — Claude handles these naturally |
| `kill_terminal` | `terminal_id` | `success` | Kills PTY process |
| `list_terminals` | — | `terminals[]` | All terminals with ID, label, status, project, cwd, last activity |

Tool names align with existing MCP tool names (`write_to_terminal`, `run_command`, `read_terminal`) so handler code can be shared.

### Project Management
| Tool | Params | Returns | Description |
|------|--------|---------|-------------|
| `create_project` | `label`, `cwd` | `project_id` | Idempotent: returns existing group if one with the same `cwd` exists, otherwise creates a new one |
| `close_project` | `project_id` | `success` | Kills all terminals, removes group |
| `list_projects` | — | `projects[]` | All groups with terminal counts and CWDs |

### Project Knowledge
| Tool | Params | Returns | Description |
|------|--------|---------|-------------|
| `read_project_knowledge` | `cwd` | `content` (markdown) | Reads project knowledge file. Returns error if `cwd` is empty/null |
| `update_project_knowledge` | `cwd`, `content` | `success` | Overwrites knowledge file. Returns error if `cwd` is empty/null |
| `scan_project` | `cwd` | structured JSON | Quick filesystem scan: language, framework, build files, entry points, test commands |

Note: `ProjectGroup.cwd` is nullable in the data model. Knowledge, decisions, and scan tools all require a valid `cwd`. Projects without a `cwd` (custom groups) cannot have knowledge files or decisions — Alfa should use `list_projects` to identify projects with valid CWDs before attempting knowledge operations.

### Filesystem
| Tool | Params | Returns | Description |
|------|--------|---------|-------------|
| `read_file` | `path` | `content` | Read file (must be within known project CWD) |
| `list_directory` | `path`, `recursive?` | `entries[]` | List directory contents |
| `run_shell_command` | `command`, `cwd`, `timeout_seconds?` | `stdout`, `stderr`, `exit_code` | Quick shell command with 30-second default timeout. Process is killed if timeout exceeded. Not for long-running processes — use `spawn_terminal` for those |

### Memory
| Tool | Params | Returns | Description |
|------|--------|---------|-------------|
| `save_decision` | `project_cwd`, `summary`, `outcome`, `tags[]` | `id` | Logs decision to Drift DB |
| `search_decisions` | `query`, `project_cwd?` | `decisions[]` | Search past decisions by text/tags |

## Terminal Communication

Alfa communicates with AI coding agents (Claude Code, Codex, etc.) running in terminals via:

1. **Keystroke injection** — `run_command` sends prompts with enter, `write_to_terminal` sends raw bytes (control sequences). Two tools matching the existing MCP convention
2. **AI-interpreted output** — `read_terminal` returns raw terminal text including ANSI escape codes (no stripping — Claude handles ANSI noise naturally and stripping risks losing meaningful formatting). Alfa feeds this back to Claude API as part of its context. Claude interprets the output semantically — understanding success/failure, code changes, errors, questions — rather than relying on regex patterns

This works with any CLI tool without requiring special protocol support.

## Project Knowledge File

Stored at `~/.config/dispatch/alfa/projects/{sha256_of_cwd}/knowledge.md`.

### Initial scan creates a skeleton:

```markdown
# Project: my-app
## Scanned: 2026-03-22

### Stack
- Language: Dart 3.11
- Framework: Flutter (desktop)
- State: Riverpod
- Database: Drift (SQLite)

### Structure
- packages/app — Main app
- packages/engine — Core engine

### Commands
- Build: `flutter build macos`
- Test: `flutter test`
- Analyze: `dart analyze`

### Entry Points
- packages/app/lib/main.dart
```

### Enriched over time by Alfa:

```markdown
### Architecture Insights
- MCP server runs on port 3900, uses shelf HTTP
- Terminal state managed by TerminalsNotifier (Riverpod)

### Patterns Learned
- State changes need _deferStateChange() to avoid build-phase conflicts

### Known Pitfalls
- Drift codegen must run after table changes

### Successful Workflows
- "Add MCP tool" → edit tools file, register in mcp_server.dart
```

### Size management:
If the file exceeds ~4000 tokens, Alfa summarizes older sections and archives detail to `knowledge_archive/`. The active file stays lean enough to fit in the system prompt.

## Persistence

### Drift Tables (2 new)

Adding tables requires bumping `schemaVersion` from 1 to 2 in `database.dart` and writing a migration in `onUpgrade` that creates the new tables. This must be handled carefully to avoid corrupting existing installs.

**`alfa_decisions`**
```
id            INTEGER PRIMARY KEY
project_cwd   TEXT
summary       TEXT
outcome       TEXT        — "success" | "failure" | "partial"
detail        TEXT NULL
tags          TEXT        — comma-separated
created_at    DATETIME
```

**`alfa_conversations`** (UI chat history display only — never fed back into the API system prompt)
```
id            INTEGER PRIMARY KEY
project_cwd   TEXT NULL
role          TEXT        — "human" | "alfa"
content       TEXT
tool_calls    TEXT NULL   — JSON of tool_use blocks
created_at    DATETIME
```

Alfa config uses the existing `Settings` table with namespaced keys (e.g., `alfa.api_key`, `alfa.max_turns`, `alfa.model`). No separate config table needed.

### File-based Storage

```
~/.config/dispatch/alfa/
  projects/
    {sha256_of_cwd}/
      knowledge.md
      knowledge_archive/
```

## System Prompt

Assembled per-interaction from three parts:

**Part 1 — Identity (static, ~500 tokens):**
Defines Alfa's role, autonomy level, communication style. No personality fluff.

**Part 2 — Project knowledge (dynamic, up to ~4000 tokens):**
Contents of `knowledge.md` for the active project. If no project knowledge exists, instructs Alfa to use `scan_project`.

**Part 3 — Recent decisions (dynamic, ~500 tokens):**
Last 10 entries from `alfa_decisions` table with outcomes. Gives Alfa recall of what it tried and what worked.

Total budget: ~6000 tokens max.

## UI Integration

### Chat Panel
New right-side panel (alongside notes/tasks/vault), toggled from sidebar:
- Message input at bottom
- Scrolling message history
- Markdown rendering for Alfa's responses
- Tool executions as collapsed cards: `▶ spawn_terminal → term-1710...`
- Streaming indicator while Alfa thinks

### Status Indicator
Small icon in status bar: idle (dot), thinking (pulsing), executing (spinning), error (red).

### Terminal Badges
Terminals spawned by Alfa show an "A" badge in the sidebar terminal list.

### No Other UI Changes
Alfa works through existing terminal/project infrastructure. Everything it does is visible in the normal UI.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Runtime | Dart module, Claude API via HTTP | Single codebase, direct provider access, API is just REST |
| Persistence | Drift DB + markdown files | Structured queries for decisions, human-readable project knowledge |
| Autonomy | Full | User wants speed over safety gates |
| Terminal comms | Keystroke injection + AI output parsing | Works with any CLI tool, Claude understands messy terminal output |
| Project knowledge | Progressive scan + enrichment | Quick start, grows smarter over time |
| Tool routing | Claude Code only (v1) | Ship orchestrator first, multi-tool routing later |
| Architecture | Agent with tool use | Clean separation, ephemeral conversations, extensible to hierarchical agents later |

## Future Extensions (Not in v1)

- Multi-tool routing (Claude Code vs Codex vs Gemini selection per task)
- Hierarchical sub-agents for parallel task monitoring
- Embedding-based semantic search over project knowledge (like OpenClaw's memory system)
- Voice input to Alfa
- Alfa-to-Alfa communication across projects
