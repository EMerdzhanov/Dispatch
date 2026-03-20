# Dispatch Roadmap

## Completed

### Sprint 1 — Core Terminal Manager
- [x] Electron + React + xterm.js + node-pty + tmux
- [x] Open project folders, spawn Shell/Claude Code terminals
- [x] Quick Launch presets (editable, Shell is permanent default)
- [x] Project tabs with terminal counts
- [x] Keyboard shortcuts (Cmd+N/T/W/D/K/Shift+P/1-9/,)
- [x] Command palette (Cmd+Shift+P) + Quick Switcher (Cmd+K)
- [x] tmux-backed sessions for persistence
- [x] Pure CSS design system (no Tailwind)

### Sprint 2 — Power Features
- [x] Working split panes (Cmd+D horizontal, Cmd+Shift+D vertical, Cmd+W exit split)
- [x] Terminal activity monitor (idle/running/success/error/waiting status dots)
- [x] Desktop notifications + sounds on success/error
- [x] Session templates (Cmd+Shift+S to save, restore from welcome screen)
- [x] Auto-resume (tmux session detection + restore modal on launch)
- [x] Terminal rename (double-click or right-click)
- [x] Settings panel with preset editor, notification toggles
- [x] Right-click tab to close tab, right-click terminal for rename/close

### Sprint 3 — Project Panels
- [x] Sidebar split — terminals on top, panels on bottom
- [x] Tasks panel — checkbox todo list with expandable descriptions
- [x] Notes panel — named notes with list/edit views
- [x] Vault panel — secrets storage with one-click copy-to-clipboard
- [x] Per-project data persistence (~/.config/dispatch/projects/)
- [x] Auto-save on edit (debounced), auto-load on project switch

## Next Up

### Sprint 4 — Built-in Browser
- [ ] Embedded Chromium browser pane (Electron WebContentsView)
- [ ] Auto-detect `localhost:XXXX` in terminal output, offer to open in browser
- [ ] Console log capture — JS errors, console.log piped back to terminal or log panel
- [ ] Network request monitoring — failed requests shown inline
- [ ] DevTools integration — toggle DevTools for the embedded browser
- [ ] Split terminal + browser side by side
- [ ] URL bar with back/forward/refresh
- [ ] Hot reload detection — auto-refresh when dev server rebuilds

## Future Ideas

### Tier 1 — High Impact
- [ ] Git status per project tab (branch name, dirty indicator)
- [ ] Cross-session search (Cmd+F across all terminal output in a project)
- [ ] Terminal output capture (right-click → Save output to file)
- [ ] Quick actions bar (Resume All, Stop All, New Claude in each project)

### Tier 2 — Power Features
- [ ] Drag-and-drop tab reordering and terminal-between-groups
- [ ] File tree sidebar (toggle between terminal list and file tree)
- [ ] Diff viewer (inline git diff when Claude makes changes)
- [ ] Resource monitor (CPU/memory per terminal process)

### Tier 3 — IDE Territory
- [ ] Agent orchestration (define tasks for multiple Claude sessions, monitor dashboard)
- [ ] Inter-session communication (shared clipboard between sessions)
- [ ] Plugin system (custom panels, custom presets, hooks)
- [ ] Vault encryption (AES with master password or OS keychain)
