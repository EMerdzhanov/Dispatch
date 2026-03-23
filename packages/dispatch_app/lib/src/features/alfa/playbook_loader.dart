import 'dart:io';

import 'default_identity.dart';

/// Parsed playbook metadata from YAML frontmatter.
class PlaybookMeta {
  final String name;
  final String description;
  final String triggers;
  final List<Map<String, String>> outputs;
  final bool draft;
  final String filePath;

  const PlaybookMeta({
    required this.name,
    required this.description,
    this.triggers = '',
    this.outputs = const [],
    this.draft = false,
    required this.filePath,
  });
}

/// Loads and manages playbook markdown files.
class PlaybookLoader {
  final String _dir;

  PlaybookLoader() : _dir = '${alfaDir()}/playbooks';

  /// List all playbooks with metadata (from frontmatter).
  Future<List<PlaybookMeta>> listPlaybooks() async {
    final dir = Directory(_dir);
    if (!await dir.exists()) return [];

    final playbooks = <PlaybookMeta>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final content = await entity.readAsString();
      final meta = _parseFrontmatter(content, entity.path);
      if (meta != null) playbooks.add(meta);
    }
    return playbooks;
  }

  /// Load a playbook's full content by name.
  Future<String?> loadPlaybook(String name) async {
    final playbooks = await listPlaybooks();
    final match = playbooks
        .where(
          (p) => p.name.toLowerCase() == name.toLowerCase(),
        )
        .firstOrNull;
    if (match == null) return null;
    return File(match.filePath).readAsString();
  }

  /// Save or update a playbook file.
  Future<String> savePlaybook(String name, String content) async {
    final fileName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
    final path = '$_dir/$fileName.md';
    await writeFile(path, content);
    return path;
  }

  /// Get a summary for the system prompt (names + descriptions + triggers).
  Future<String> getPromptSummary() async {
    final playbooks = await listPlaybooks();
    if (playbooks.isEmpty) return 'No playbooks available.';
    return playbooks.map((p) {
      final draft = p.draft ? ' [DRAFT]' : '';
      return '- **${p.name}**$draft: ${p.description} (triggers: ${p.triggers})';
    }).join('\n');
  }

  /// Create default playbooks if the directory is empty.
  Future<void> ensureDefaults() async {
    final dir = Directory(_dir);
    await dir.create(recursive: true);
    final existing =
        await dir.list().where((e) => e.path.endsWith('.md')).length;
    if (existing > 0) return;

    const playbooks = {
      'code-review.md': _codeReviewPlaybook,
      'debug-workflow.md': _debugPlaybook,
      'feature-build.md': _featureBuildPlaybook,
      'test-and-fix.md': _testAndFixPlaybook,
      'git-workflow.md': _gitWorkflowPlaybook,
    };

    for (final entry in playbooks.entries) {
      await writeFile('$_dir/${entry.key}', entry.value);
    }
  }

  /// Parse YAML frontmatter from markdown.
  PlaybookMeta? _parseFrontmatter(String content, String filePath) {
    if (!content.startsWith('---')) return null;
    final endIndex = content.indexOf('---', 3);
    if (endIndex == -1) return null;

    final yaml = content.substring(3, endIndex).trim();
    String? name, description, triggers;
    bool draft = false;

    for (final line in yaml.split('\n')) {
      final colonIdx = line.indexOf(':');
      if (colonIdx == -1) continue;
      final key = line.substring(0, colonIdx).trim();
      final value = line.substring(colonIdx + 1).trim();

      switch (key) {
        case 'name':
          name = value;
        case 'description':
          description = value;
        case 'triggers':
          triggers = value;
        case 'draft':
          draft = value == 'true';
      }
    }

    if (name == null || description == null) return null;
    return PlaybookMeta(
      name: name,
      description: description,
      triggers: triggers ?? '',
      draft: draft,
      filePath: filePath,
    );
  }
}

// ─── Default Playbook Constants ────────────────────────────────────────────

const _codeReviewPlaybook = '''---
name: Code Review
description: Orchestrate a code review by delegating file analysis to a terminal agent
triggers: review, code review, check this code, audit
outputs:
  - type: summary
    format: markdown
---

## Steps

1. Load project context
2. Identify files to review (ask human if unclear)
3. Spawn a terminal with Claude Code
4. Brief it: "Review these files for bugs, security issues, and code quality. Report findings with file:line references."
5. Monitor until complete
6. Read output, synthesize into a clean summary
7. Ask human if any findings should be actioned
8. If yes, delegate fixes to a new terminal

## History
''';

const _debugPlaybook = '''---
name: Debug Workflow
description: Systematically diagnose and fix a bug by delegating investigation to a terminal agent
triggers: debug, fix bug, something is broken, not working, error
outputs:
  - type: fix
    format: diff
---

## Steps

1. Load project context
2. Ask human to describe the bug and how to reproduce it
3. Spawn a terminal with Claude Code
4. Brief it: "Investigate this bug: [description]. Find the root cause and propose a fix."
5. Monitor until complete
6. Review findings and proposed fix with human
7. If approved, delegate implementation to a new terminal
8. Verify fix by asking human to confirm

## History
''';

const _featureBuildPlaybook = '''---
name: Feature Build
description: Plan and implement a new feature by coordinating design, implementation, and testing
triggers: build feature, add feature, implement, new feature, create
outputs:
  - type: implementation
    format: code
---

## Steps

1. Load project context
2. Clarify feature requirements with human
3. Break feature into subtasks
4. Spawn a terminal with Claude Code for design/planning
5. Brief it: "Design the implementation for: [feature]. Identify files to modify and create."
6. Review design with human
7. Spawn a new terminal for implementation
8. Brief it: "Implement the design: [design summary]. Follow existing code style."
9. Monitor until complete
10. Review output and run tests

## History
''';

const _testAndFixPlaybook = '''---
name: Test and Fix
description: Run the test suite, identify failures, and delegate fixes to a terminal agent
triggers: run tests, test, failing tests, fix tests, ci failing
outputs:
  - type: report
    format: markdown
---

## Steps

1. Load project context
2. Spawn a terminal with Claude Code
3. Brief it: "Run the full test suite. Report all failures with file:line references and error messages."
4. Monitor until complete
5. Parse failures and group by component
6. For each failure group, spawn a fix terminal
7. Brief it: "Fix these test failures: [list]. Do not change test expectations unless they are clearly wrong."
8. Re-run tests to confirm all pass
9. Summarize changes made

## History
''';

const _gitWorkflowPlaybook = '''---
name: Git Workflow
description: Manage git operations including staging, committing, branching, and pull requests
triggers: commit, git, push, pull request, pr, branch, stage
outputs:
  - type: git-actions
    format: list
---

## Steps

1. Load project context
2. Ask human what git operation is needed (commit, PR, branch, etc.)
3. Spawn a terminal with Claude Code
4. Brief it: "Perform the following git operation: [operation]. Follow the project's commit message conventions."
5. Monitor until complete
6. Review the result with human
7. If creating a PR, draft title and description for human approval
8. Execute push/PR creation after approval

## History
''';
