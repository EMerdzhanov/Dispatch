# Semantic Memory System — Design Spec

**Date:** 2026-03-25
**Status:** Approved
**Sub-project:** 1 of 7 (Dispatch Next)

## Overview

Replace Grace's flat-file memory (`memory.md`) with a structured, Claude-scored semantic memory system. Memories are stored in SQLite via Drift, pre-filtered by tags and project scope, and scored for relevance by Claude at conversation start. No embeddings, no vector DB — Claude IS the relevance engine.

## Data Model

New Drift table `GraceMemories`:

| Column | Type | Description |
|--------|------|-------------|
| `id` | int (auto) | Primary key |
| `projectCwd` | text (nullable) | null = global, set = project-specific |
| `category` | text | One of: `preference`, `decision`, `correction`, `context`, `workflow` |
| `content` | text | The memory itself (unique per projectCwd) |
| `tags` | text | Lowercase, hyphen-separated keywords. Max 20 chars per tag. e.g. `coding-style,formatting` |
| `pinned` | bool | Always included in system prompt |
| `source` | text | One of: `user_explicit`, `grace_suggested`, `correction` |
| `createdAt` | datetime | When the memory was created |
| `lastRetrievedAt` | datetime (nullable) | Last time this memory was scored as relevant |

**Constraints:**
- Unique on `(projectCwd, content)` to prevent duplicate memories
- Before insert, check for existing memory with same content; update instead of duplicate

New DAO: `GraceMemoriesDao` with methods:

```dart
Future<List<GraceMemory>> getAll();
Future<List<GraceMemory>> getPinned();
Future<List<GraceMemory>> getForProject(String? cwd);
// Candidates: project-specific + global, ordered by createdAt desc
Future<List<GraceMemory>> getCandidates(String? cwd, {int limit = 50});
Future<int> insertMemory(GraceMemoriesCompanion entry);
// Only content, tags, and category are updatable
Future<void> updateMemory(int id, {String? content, String? tags, String? category});
Future<void> setPinned(int id, bool pinned);
Future<void> touchRetrieved(List<int> ids); // set lastRetrievedAt = now
Future<void> deleteMemory(int id);
// Memories where lastRetrievedAt < (now - threshold) AND lastRetrievedAt is not null
Future<List<GraceMemory>> getStale({int thresholdDays = 90});
```

**Schema migration:**
- Bump `schemaVersion` to `3`
- Migration: `if (from < 3) { await m.createTable(graceMemories); }`

## Memory Lifecycle

### Saving — 3 Triggers

**1. User explicit:**
User says "remember that we use PostgreSQL 16 in production."
Grace calls `save_memory` immediately, confirms: "Saved to memory."

**2. Grace-suggested:**
During conversation, Grace detects a preference, decision, or workflow pattern.
She asks: "I noticed you prefer snake_case for database columns. Want me to remember that?"
User confirms → saved. User declines → dropped. If user ignores, Grace does not re-ask.

**3. Corrections:**
User corrects Grace: "No, we use REST not GraphQL here."
Grace asks: "Got it — REST not GraphQL. Save this so I don't forget?"
User confirms → saved with `source: 'correction'`.

Detection is handled by Grace's system prompt behavioral instructions, not code-level pattern matching.

### Retrieval — Per Conversation

```
1. Load all pinned memories (max ~20)
2. Pull candidates:
   - Filter: projectCwd matches OR projectCwd is null (global)
   - Limit: 50 candidates, ordered by createdAt desc
3. Claude relevance scoring (side-request):
   - See "Relevance Scoring Request Format" below
   - Returns IDs of relevant memories (~5-15)
4. Update lastRetrievedAt on retrieved memory IDs
5. Inject into system prompt:
   - "## Pinned Memories" section (max 3000 tokens)
   - "## Relevant Memories" section (max 2000 tokens)
   - If section exceeds budget, truncate oldest entries first
```

The relevance scoring runs once at conversation start. It is a blocking async call — conversation doesn't begin until memories are loaded.

### Relevance Scoring Request Format

Uses the existing `ClaudeClient` with a small, non-streaming request.

**System prompt for scoring request:**
```
You are a memory relevance scorer. Given a conversation context and a list of memories,
return the IDs of memories that are relevant to this conversation. Return only the JSON array of IDs.
```

**User message:**
```json
{
  "context": "User is asking about database migration for the Dispatch project",
  "memories": [
    {"id": 1, "content": "User prefers tabs over spaces", "category": "preference", "tags": "formatting"},
    {"id": 5, "content": "Chose PostgreSQL 16 for production", "category": "decision", "tags": "database,infra"},
    {"id": 12, "content": "REST API, not GraphQL", "category": "correction", "tags": "api"}
  ]
}
```

**Expected response (parsed as JSON):**
```json
[5, 12]
```

**Error handling:**
- If Claude API call fails (network, rate limit, etc.), fall back to returning ALL candidates (unscored). Conversation proceeds with potentially noisy memories rather than failing.
- If response is not valid JSON, fall back to all candidates.
- Timeout: 10 seconds. If exceeded, fall back to all candidates.

**Implementation:** New file `memory_retrieval.dart` with a single function:
```dart
Future<List<int>> scoreMemoryRelevance(
  ClaudeClient client,
  String conversationContext,
  List<GraceMemory> candidates,
) async { ... }
```

### Memory Decay

Stale memory check runs **once per conversation start**, after retrieval:
1. Query `getStale(thresholdDays: 90)`
2. If stale memories exist, Grace mentions at the start of conversation: "I have N old memories that haven't been relevant recently. Want to review them in the Memory panel?"
3. This message is informational only — no automatic deletion. User reviews/deletes via Memory panel.
4. Grace only asks once per session (tracked in-memory, not persisted).

## Tool Architecture

**Two separate tool sets, same underlying database:**

| Tool Set | Location | Used By | Purpose |
|----------|----------|---------|---------|
| Grace-native tools | `features/grace/tools/grace_memory_tools.dart` | Grace orchestrator | Save/recall/manage during chat |
| MCP tools | `features/mcp/tools/memory_tools.dart` | External agents via MCP | Read/write memory for remote agents |

Grace-native tools use `GraceToolEntry` format. MCP tools use `McpToolDefinition` format. Both read/write the same `GraceMemories` table. The existing MCP `memory_tools.dart` (which currently reads/writes flat files) is updated to use the database instead.

**Grace-native tools (6 tools in `grace_memory_tools.dart`):**

| Tool | Params | Description |
|------|--------|-------------|
| `save_memory` | `content`, `category`, `tags?`, `projectCwd?`, `pinned?` | Save a memory. Grace calls after user confirmation. |
| `recall_memories` | `context` | Retrieve relevant memories for given context text. Returns scored list. |
| `list_memories` | `category?`, `projectCwd?` | List memories, optionally filtered. |
| `delete_memory` | `id` | Delete by ID. |
| `pin_memory` | `id` | Pin a memory. |
| `unpin_memory` | `id` | Unpin a memory. |

**MCP tools (updated, 4 tools in `mcp/tools/memory_tools.dart`):**

| Tool | Change |
|------|--------|
| `read_memory` | Now reads from DB: returns pinned + recent memories as formatted text |
| `update_memory` | Now calls `insertMemory` on the DB instead of overwriting file |
| `append_log` | Unchanged — still writes to `log.md` |
| `read_log` | Unchanged — still reads from `log.md` |

## System Prompt Changes

Replace the flat `memory.md` dump in `_buildSystemPrompt()` with structured sections.

**Prompt order:** Identity → **Workspace Tools instruction** → **Pinned Memories** → **Relevant Memories** → Project Knowledge → Playbooks → Agent State → Recent Log → Current Tasks → Notes → Test Status

**Pinned Memories section (max 3000 tokens):**
```markdown
## Pinned Memories
- [preference] User prefers tabs, 2-space indent
- [workflow] Always run tests before committing
```

**Relevant Memories section (max 2000 tokens):**
```markdown
## Relevant Memories
- [decision] Chose Riverpod over Bloc for state management
- [correction] REST API, not GraphQL — corrected 2026-03-20
```

If a section exceeds its token budget, drop the oldest entries first.

**Behavioral instruction (after identity, before memories):**
```
## Memory Behavior
You have a persistent memory system. When you notice the user:
- Expressing a preference ("I prefer...", "don't use...", "always...")
- Making a technical decision ("we're going with...", "let's use...")
- Correcting you ("no, it's actually...", "not X, Y")
- Sharing team/people context ("John handles...", "the backend team...")
- Describing a workflow ("before deploying, always...", "our process is...")

Ask: "Want me to remember that?" or similar. Use save_memory after they confirm.
If the user ignores the question, do not re-ask about the same topic.
Categorize as: preference, decision, correction, context, or workflow.
```

## Migration

On first launch after update (in `GraceOrchestrator.initialize()`):

1. Check if `~/.config/dispatch/grace/memory.md` exists AND `memory.md.migrated` does NOT exist
2. Read `memory.md` content
3. Split into entries:
   - Lines starting with `- ` or `* ` → individual entries
   - Markdown headers (`## Section`) → category hint for entries below them
   - Blank lines separate logical groups
4. Category inference from section headers:
   - "Preferences" / "Style" / "Formatting" → `preference`
   - "Decisions" / "Architecture" / "Tech" → `decision`
   - "People" / "Team" / "Context" → `context`
   - "Workflow" / "Process" → `workflow`
   - Unmatched → `preference` (safe default)
5. Insert each as global memory: `projectCwd: null, source: 'user_explicit'`
6. Auto-generate tags: first 3 significant words from content, lowercased, hyphenated
7. Rename `memory.md` → `memory.md.migrated`
8. Append to `log.md`: "Migrated N memories from memory.md to database"

**Example:**
```markdown
# memory.md (before)
## User Preferences
- Prefers tabs over spaces, 2-space width
- Dark mode only, high contrast

## Project Decisions
- Using Riverpod for state management
```

**Migrated to:**
```
[preference] "Prefers tabs over spaces, 2-space width" tags: "tabs,spaces,formatting" pinned: false
[preference] "Dark mode only, high contrast" tags: "dark-mode,ui" pinned: false
[decision] "Using Riverpod for state management" tags: "riverpod,state" pinned: false
```

## UI: Memory Panel

New tab in the Project panel (right sidebar), alongside Tasks / Notes / Vault.

**Layout:**
- Tab label: "Memory" with brain icon (Icons.psychology)
- Grouped sections: Pinned → Project Memories → Global Memories
- Global section collapsed by default
- Count badge on tab when memories exist

**Memory card:**
- Content text truncated at 200 chars; click to expand full text
- Category badge (color-coded pill)
- Age ("3 days ago") using relative time
- Pin toggle button (filled/outline pushpin icon)
- Delete button (X) — shows confirmation dialog before removal
- Click content to edit inline: text becomes a TextField, blur or Enter saves, Escape cancels

**Category colors:**
- preference: blue (`accentBlue`)
- decision: green (`accentGreen`)
- correction: orange (`accentYellow`)
- context: purple (`Color(0xFF9B59B6)`)
- workflow: teal (`Color(0xFF1ABC9C)`)

**Empty state:** "No memories yet. Chat with Grace — she'll learn as you go."

## Files Affected

**New files:**
- `lib/src/core/database/tables.dart` — add `GraceMemories` table class
- `lib/src/core/database/daos.dart` — add `GraceMemoriesDao`
- `lib/src/features/grace/tools/grace_memory_tools.dart` — 6 Grace-native memory tools
- `lib/src/features/grace/memory_retrieval.dart` — Claude relevance scoring function
- `lib/src/features/grace/memory_migration.dart` — flat file → DB migration
- `lib/src/features/sidebar/memory_panel.dart` — Memory tab UI widget

**Modified files:**
- `lib/src/core/database/database.dart` — register table + DAO, bump schema to 3, add migration
- `lib/src/features/grace/grace_orchestrator.dart` — replace memory.md dump with retrieval flow, add behavioral instruction, call migration on initialize
- `lib/src/features/projects/project_panel.dart` — add Memory tab
- `lib/src/features/mcp/tools/memory_tools.dart` — update `read_memory` and `update_memory` to use DB

**Regenerated files:**
- `lib/src/core/database/daos.g.dart`
- `lib/src/core/database/database.g.dart`

## Success Criteria

1. Grace remembers corrections across conversations
2. Memories are scoped correctly (project vs global)
3. Pinned memories always appear in system prompt
4. Irrelevant memories don't bloat the prompt (max 5000 tokens total)
5. Memory panel shows all entries grouped, editable and deletable
6. Old memory.md content migrated without data loss
7. No new API dependencies — uses existing Claude key
8. Relevance scoring gracefully falls back on API failure
9. No duplicate memories stored
