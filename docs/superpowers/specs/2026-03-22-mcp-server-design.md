# MCP Server Integration Design

**Date:** 2026-03-22
**Status:** Approved

## Overview

Dispatch exposes a Model Context Protocol (MCP) server so AI coding agents (Claude Code, OpenClaw, etc.) can remotely observe, control, and orchestrate terminal sessions and projects. The server is built natively in Dart inside the Flutter app, using `shelf` for HTTP/SSE and `json_rpc_2` for protocol handling.

## Target Consumers

- Claude Code
- OpenClaw
- Any MCP-compatible AI coding agent

## Architecture

```
┌─────────────────────────────────────┐
│         MCP Tool Handlers           │  ← ref.read() into Riverpod providers
├─────────────────────────────────────┤
│        MCP Protocol Layer           │  ← JSON-RPC 2.0 request/response + notifications
├──────────┬──────────────────────────┤
│  stdio   │   HTTP/SSE (shelf)       │  ← Transport layer
└──────────┴──────────────────────────┘
```

- **Transport layer:** HTTP/SSE via `shelf` on a configurable port. stdio via a thin Dart entry point that bridges stdin/stdout.
- **Protocol layer:** JSON-RPC 2.0 message parsing, routing to tool handlers, response formatting, and notification push over SSE.
- **Tool handlers:** Functions that read/write Riverpod state. Each tool is a function that uses `ref` from the parent `McpServerNotifier` and request parameters.

The server is started/stopped by `McpServerNotifier` which extends `Notifier<McpServerState>`. It gets `ref` from the Riverpod base class (same pattern as `AutoSaveNotifier` which extends `Notifier<void>`). `McpServer` is instantiated inside `McpServerNotifier.build()` with `ref` passed through. The Integrations icon in the tab bar toggles it and shows connection status.

MCP settings are read directly from the database at startup by `McpServerNotifier` via `settingsDao.getValue(...)` and stored only in `McpServerState` — they do not go into `AppSettings`. This keeps the MCP feature self-contained. The settings keys (`mcp_enabled`, `mcp_port`, `mcp_auth_enabled`, `mcp_auth_token`) are written to the Settings KV store by `McpServerNotifier` when the user changes them in the Integrations panel.

## Terminal Buffer Access

`read_terminal` needs to extract text from xterm's `Terminal` object. Two mechanisms work together:

1. **Rolling output accumulator:** Each `TerminalPane` already receives PTY output in its `onOutput` callback. We add a per-terminal `Queue<String>` capped at 10,000 lines, stored in `SessionRegistry` alongside the `PtySession`. When a new line arrives and the queue exceeds the cap, the oldest line is dequeued. This captures all output including scrollback that has left the screen. This is the primary source for `read_terminal`.

2. **Screen buffer fallback:** The xterm `Terminal.buffer` exposes `lines` (a `CircularList<BufferLine>`). Each `BufferLine` has a `getString()` method to extract text. This can be used to read what's currently visible on screen. However, this is only available when the terminal widget is rendered.

**Canonical PTY/terminal access:** `SessionRegistry` (the existing Riverpod provider at `session_registry.dart`) is the canonical source for PTY access from tool handlers — not the static `TerminalPane.terminalRegistry` map, which is tied to widget lifecycle and may be empty for terminals whose widgets are not currently mounted. `SessionRegistry` will be extended to also hold the output accumulator buffer per terminal.

## Terminal Status

`TerminalEntry.status` tracks `active`/`running`/`exited` with exit codes. `TerminalMonitor` tracks `idle`/`running`/`success`/`error` with idle duration, but is an imperative object not accessible via `Ref`.

**Resolution:** Promote idle detection to `SessionRegistry`. `TerminalMonitor` is an imperative class instantiated in the widget tree — it has no `ref`. The bridge is wired at construction time: `TerminalPane` passes a callback into `TerminalMonitor`'s constructor (alongside existing `onStatusChange` and `onUrlDetected`) that calls `ref.read(sessionRegistryProvider.notifier).updateMeta(terminalId, ...)`. When `TerminalMonitor` detects idle state or status changes, it invokes this callback, which writes the timestamp and status into a `TerminalSessionMeta` record in `SessionRegistry`. Tool handlers read idle duration from `ref.read(sessionRegistryProvider).getMeta(terminalId)`.

## MCP Tools (14 total)

### Observe

| Tool | Parameters | Returns |
|---|---|---|
| `list_projects` | none | Array of `{id, label, cwd, terminalIds}` |
| `get_active_project` | none | `{id, label, cwd, terminalIds}` or null |
| `list_terminals` | optional `projectId` | Array of `{id, command, cwd, status, label, exitCode}` |
| `read_terminal` | `terminalId`, optional `lines` (default 100) | `{terminalId, content: string, lineCount: int}` |
| `get_terminal_status` | `terminalId` | `{status, exitCode, idleDurationMs}` |

### Act

| Tool | Parameters | Returns |
|---|---|---|
| `run_command` | `terminalId`, `command` | `{success: bool}` — writes command + newline to PTY |
| `spawn_terminal` | `command`, `cwd`, optional `projectId`, optional `label` | `{terminalId, projectId}` |
| `kill_terminal` | `terminalId` | `{success: bool}` |
| `write_to_terminal` | `terminalId`, `input` | `{success: bool}` — writes raw input to PTY (no newline) |

### Orchestrate

| Tool | Parameters | Returns |
|---|---|---|
| `create_project` | `label`, `cwd` | `{projectId}` |
| `close_project` | `projectId` | `{success: bool}` — closes all terminals in group |
| `set_active_project` | `projectId` | `{success: bool}` |
| `set_active_terminal` | `terminalId` | `{success: bool}` |
| `split_terminal` | `terminalId` (source pane), `direction` (`horizontal`/`vertical`), optional `newTerminalId` (existing terminal to place) or `command`+`cwd` (spawn new) | `{terminalId}` — returns the ID of the terminal placed in the new pane. Mutates `ProjectGroup.splitLayout` by wrapping the source leaf into a `SplitBranch` with the specified direction and adding a new `SplitLeaf` for the target terminal. `SplitNode` types are anonymous (no IDs) — they are identified by tree position only. |

## Transport & Connection Details

### HTTP/SSE Mode

- `shelf` server listens on `localhost:3900` by default, falls back to next available port if taken
- Endpoints:
  - `POST /mcp` — JSON-RPC 2.0 request/response (Streamable HTTP)
  - `GET /mcp/sse` — SSE stream for server-initiated notifications
  - `GET /mcp/health` — health check, returns server version and connection count
- When token auth is enabled, all endpoints require `Authorization: Bearer <token>` header
- Token is persisted in Settings KV store as `mcp_auth_token` so it survives restarts. User can regenerate it from the Integrations panel.

### stdio Mode

- Separate Dart entry point (`packages/dispatch_app/bin/dispatch_mcp_stdio.dart`) is a standalone process that connects to the running Dispatch app's HTTP server via loopback HTTP (`http://localhost:<port>/mcp`)
- Dispatch writes a config snippet for agents to consume (e.g., Claude Code's `.mcp.json`). When token auth is enabled, the snippet includes the token in the configuration so the stdio bridge can authenticate.
- stdin/stdout carries JSON-RPC 2.0 messages

### Notifications (server to agent)

- `terminal_output` — pushed when a terminal produces new output (debounced, ~200ms)
- `terminal_status_changed` — pushed when a terminal starts, exits, or goes idle
- `project_changed` — pushed when projects are added/removed/switched

**Subscription model:** All notifications are broadcast to all connected SSE clients. No per-terminal subscription mechanism — clients filter on their end by `terminalId` in the notification payload. This keeps the server simple; agents that only care about specific terminals ignore the rest.

## Authentication & Security

- **Default:** localhost-only, no auth required
- **Optional token auth:** random token generated once and persisted in Settings KV store. Required via `Authorization: Bearer <token>` header. Regenerate button in Integrations panel.
- **Network access:** toggle to bind to all interfaces (off by default, with warning in UI)
- **Permissions:** full access once connected — no per-tool restrictions

## Integrations Panel UI

Accessible via the existing `Icons.extension_outlined` button in the tab bar. Opens as an overlay panel (same pattern as settings).

### Sections

**Server Status**
- Toggle switch: MCP Server on/off
- Status indicator: running/stopped, port number
- Connection count: "2 agents connected"

**Connection Info**
- HTTP URL: `http://localhost:3900/mcp` (copyable)
- Auth token (if enabled): shown masked, click to reveal, copy button
- Regenerate token button
- Claude Code config snippet: ready-to-paste JSON block for `.mcp.json` including token if enabled (copy button)

**Settings**
- Port number (text field, default 3900)
- Auth token toggle: on/off
- Network access toggle: localhost-only vs. all interfaces (off by default, with warning)

**Activity Log**
- Scrollable list of recent MCP requests: timestamp, tool name, agent identifier

## File Structure

### New Files

```
packages/dispatch_app/lib/src/features/mcp/
├── mcp_provider.dart          # McpServerNotifier extends Notifier<McpServerState> — start/stop, state
├── mcp_server.dart            # shelf server setup, SSE management, JSON-RPC routing
├── mcp_protocol.dart          # JSON-RPC 2.0 parsing, request/response/notification types
├── mcp_tools.dart             # Tool registry — maps tool names to handlers
├── tools/
│   ├── observe_tools.dart     # list_projects, list_terminals, read_terminal, etc.
│   ├── act_tools.dart         # run_command, spawn_terminal, kill_terminal, etc.
│   └── orchestrate_tools.dart # create_project, close_project, split_terminal, etc.
├── mcp_notifications.dart     # Riverpod listeners that push SSE notifications on state changes
└── mcp_panel.dart             # Integrations panel UI

packages/dispatch_app/bin/
└── dispatch_mcp_stdio.dart    # stdio entry point for Claude Code integration
```

### Existing Files Modified

- `tab_bar.dart` — add `onOpenIntegrations` callback (following existing `onOpenSettings`/`onOpenShortcuts` pattern), wire the Integrations icon, show status dot when server is running
- `app.dart` — add `_integrationsOpen` bool state, wire `onOpenIntegrations` callback to `ProjectTabBar`, add `McpPanel` overlay to the builder stack (same pattern as settings/shortcuts overlays)
- `session_registry.dart` — extend to hold per-terminal output accumulator (`Queue<String>` capped at 10,000 lines) and `TerminalSessionMeta` (idle timestamp, monitor status). Add `updateMeta()` and `appendOutput()` methods to the notifier.
- `terminal_pane.dart` — feed PTY output into `SessionRegistry` output accumulator in the `onOutput` callback. Pass a meta-update callback to `TerminalMonitor` constructor.
- `terminal_monitor.dart` — accept and invoke a new `onMetaUpdate` callback for idle/status changes (no `ref` needed — callback is wired by `TerminalPane`)
- `main.dart` — auto-start MCP server on launch if `mcp_enabled` is persisted as true

## Dependencies

### New

- `shelf` + `shelf_router` — HTTP server and routing
- `json_rpc_2` — JSON-RPC 2.0 protocol handling

### Existing (no changes needed)

- `dart:io` — stdio transport
- `dart:math` — token generation (Random.secure())
- `uuid` — already in project
