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
- **Tool handlers:** Functions that read/write Riverpod state. Each tool is a function that receives a `Ref` and request parameters.

The server is started/stopped by `McpServerNotifier` (Riverpod provider). The Integrations icon in the tab bar toggles it and shows connection status. A new `mcp_enabled` setting in SQLite persists the toggle across restarts.

## MCP Tools (14 total)

### Observe

| Tool | Description |
|---|---|
| `list_projects` | Returns all project groups with their IDs, labels, cwds, and terminal IDs |
| `get_active_project` | Returns the currently active project group |
| `list_terminals` | Returns all terminals with ID, command, cwd, status, label |
| `read_terminal` | Returns the screen buffer content of a terminal by ID (last N lines, default 100) |
| `get_terminal_status` | Returns status (running/exited), exit code, and idle duration for a terminal |

### Act

| Tool | Description |
|---|---|
| `run_command` | Sends a command string to an existing terminal (writes to its PTY) |
| `spawn_terminal` | Creates a new terminal with a given command and cwd, optionally in a specific project group |
| `kill_terminal` | Kills a terminal's PTY process |
| `write_to_terminal` | Writes raw text/keystrokes to a terminal's PTY (for interactive programs) |

### Orchestrate

| Tool | Description |
|---|---|
| `create_project` | Creates a new project group with a label and cwd |
| `close_project` | Closes a project group and all its terminals |
| `set_active_project` | Switches the active project tab |
| `set_active_terminal` | Switches the active terminal within the current project |
| `split_terminal` | Splits the current view and places a terminal in the new pane |

## Transport & Connection Details

### HTTP/SSE Mode

- `shelf` server listens on `localhost:3900` by default, falls back to next available port if taken
- Endpoints:
  - `POST /mcp` — JSON-RPC 2.0 request/response (Streamable HTTP)
  - `GET /mcp/sse` — SSE stream for server-initiated notifications
  - `GET /mcp/health` — health check, returns server version and connection count
- When token auth is enabled, all endpoints require `Authorization: Bearer <token>` header
- Token is auto-generated on server start, displayed in the Integrations panel, copyable

### stdio Mode

- Separate Dart entry point (`bin/dispatch_mcp_stdio.dart`) connects to the running Dispatch app's HTTP server internally
- Dispatch can write a config snippet for agents to consume (e.g., Claude Code's `.mcp.json`)
- stdin/stdout carries JSON-RPC 2.0 messages

### Notifications (server to agent)

- `terminal_output` — pushed when a terminal produces new output (debounced)
- `terminal_status_changed` — pushed when a terminal starts, exits, or goes idle
- `project_changed` — pushed when projects are added/removed/switched

Agents subscribe to notifications for specific terminal IDs or receive all events.

## Authentication & Security

- **Default:** localhost-only, no auth required
- **Optional token auth:** auto-generated random token, required via `Authorization: Bearer <token>` header
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
- Claude Code config snippet: ready-to-paste JSON block for `.mcp.json` (copy button)

**Settings**
- Port number (text field, default 3900)
- Auth token toggle: on/off
- Network access toggle: localhost-only vs. all interfaces (off by default, with warning)

**Activity Log**
- Scrollable list of recent MCP requests: timestamp, tool name, agent identifier

## File Structure

### New Files

```
lib/src/features/mcp/
├── mcp_provider.dart          # McpServerNotifier — start/stop, state (port, running, connections, token)
├── mcp_server.dart            # shelf server setup, SSE management, JSON-RPC routing
├── mcp_protocol.dart          # JSON-RPC 2.0 parsing, request/response/notification types
├── mcp_tools.dart             # Tool registry — maps tool names to handlers
├── tools/
│   ├── observe_tools.dart     # list_projects, list_terminals, read_terminal, etc.
│   ├── act_tools.dart         # run_command, spawn_terminal, kill_terminal, etc.
│   └── orchestrate_tools.dart # create_project, close_project, split_terminal, etc.
├── mcp_notifications.dart     # Riverpod listeners that push SSE notifications on state changes
└── mcp_panel.dart             # Integrations panel UI

bin/
└── dispatch_mcp_stdio.dart    # stdio entry point for Claude Code integration
```

### Existing Files Modified

- `tables.dart` — add `mcp_enabled`, `mcp_port`, `mcp_auth_enabled` to Settings
- `tab_bar.dart` — wire Integrations icon to open `McpPanel`, show status dot when server is running
- `terminal_pane.dart` — expose terminal screen buffer reading via existing `TerminalPane.terminalRegistry` static map
- `main.dart` — optionally auto-start MCP server on launch if `mcp_enabled` is persisted

## Dependencies

### New

- `shelf` + `shelf_router` — HTTP server and routing
- `json_rpc_2` — JSON-RPC 2.0 protocol handling

### Existing (no changes needed)

- `dart:io` — stdio transport
- `dart:math` — token generation (Random.secure())
- `uuid` — already in project

## Key Integration Detail

Tool handlers need Riverpod `Ref` access. `McpServer` receives a `Ref` when constructed by the provider, passing it to each tool handler. This follows the same pattern as `AutoSaveNotifier`.

Terminal buffer access uses the existing `TerminalPane.terminalRegistry` static map, which already holds xterm `Terminal` objects keyed by terminal ID.
