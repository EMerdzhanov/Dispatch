# Cloudflare Tunnel Integration Design

**Date:** 2026-03-22
**Status:** Approved

## Overview

Add built-in Cloudflare Tunnel support to Dispatch's MCP server, allowing remote AI agents (Claude app, OpenClaw, etc.) to connect to the local MCP server via a public URL. Dispatch manages the `cloudflared` process lifecycle — users just toggle a switch.

## How It Works

Dispatch spawns `cloudflared tunnel --url http://localhost:<port>` as a child process. The `cloudflared` binary creates a free quick tunnel via Cloudflare's `trycloudflare.com` service (no account required). Dispatch parses the generated public URL from the process output and displays it in the Integrations panel.

## Detection & Install Flow

1. On Integrations panel open, run `which cloudflared` to check availability
2. If not found: show install prompt with "Install cloudflared" button
   - Button spawns a terminal with `brew install cloudflared`
   - Also shows manual download link as fallback
3. If found: show the "Public URL" toggle
4. Cache the detection result in `McpServerState.cloudflaredAvailable` — re-check on each panel open

## Tunnel Lifecycle

- **Start:** `Process.start('cloudflared', ['tunnel', '--url', 'http://localhost:$port'])`
- **URL parsing:** `cloudflared` outputs the URL to stderr in the format `https://xxx.trycloudflare.com`. Parse it with a regex match on the output stream.
- **State:** Store `tunnelUrl` and `tunnelRunning` in `McpServerState`
- **Stop:** Kill the `cloudflared` process (`process.kill()`)
- **App exit:** `ref.onDispose` kills the process if still running
- **Server dependency:** Tunnel toggle is only enabled when the MCP server is running. If the server is stopped while tunnel is active, stop the tunnel too.

## UI Changes to Integrations Panel

New section in the panel between CONNECTION and SETTINGS:

**PUBLIC ACCESS**
- "Public URL" toggle
  - Disabled with install prompt if `cloudflared` not found
  - Disabled if MCP server is not running
- When starting: status text "Starting tunnel..."
- When active: shows `https://xxx.trycloudflare.com` URL with copy button, status "Tunnel active"
- When stopped: status "Tunnel stopped"

**CONNECTION section changes:**
- URL row shows tunnel URL when tunnel is active, localhost when not
- Claude Code config snippet automatically uses tunnel URL when active, localhost when not
- Both update reactively via `McpServerState`

## Files Modified

- `mcp_provider.dart` — Add to `McpServerState`: `tunnelUrl` (String?), `tunnelRunning` (bool), `tunnelStarting` (bool), `cloudflaredAvailable` (bool). Add to `McpServerNotifier`: `checkCloudflared()`, `startTunnel()`, `stopTunnel()`. Store the `Process` handle. Update `stopServer()` to also stop tunnel. Update `httpUrl` getter and `claudeCodeConfig()` to return tunnel URL when active.
- `mcp_panel.dart` — Add PUBLIC ACCESS section with tunnel toggle, URL display, and install prompt. Call `checkCloudflared()` on panel open. Disable tunnel toggle when server is not running.

## No New Dependencies

`cloudflared` is an external binary managed by the user. Dispatch uses `dart:io` `Process` to spawn and manage it. No new Dart packages required.
