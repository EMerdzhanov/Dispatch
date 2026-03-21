# Dispatch Visual Polish — Design Spec

## Overview

A visual refinement pass across all existing widgets in the Flutter Dispatch app. No layout changes, no new features, no new components — just making every existing pixel feel intentional and premium.

The goal: close the visual gap between "dev tool" and "polished product" (Cursor/VS Code level) while staying terminal-first.

## 1. Typography System

Strict 3-size system with consistent weight rules:

| Use | Size | Weight | Tracking |
|-----|------|--------|----------|
| Section labels (QUICK LAUNCH, TERMINALS, FILES) | 10px | w600 | 0.8px, uppercase |
| Body text (terminal names, settings, notes, file names) | 12px | w400 | 0 |
| Titles (tab names, panel headers, welcome title) | 14px | w500 | 0 |

Additional:
- Badge text (terminal count): 9px, w500, inside pill-shaped containers
- Title bar hints: 10px
- Remove all 11px, 13px, 15px mixed usage — snap to 10/12/14
- All `FontWeight.w600` in body text drops to `w500`

## 2. Spacing System

8px grid. Every padding, margin, gap is a multiple of 4 or 8.

| Element | Current | New |
|---------|---------|-----|
| Tab bar height | 38px | 32px |
| Sub-tab bar height | 28px | 28px (keep) |
| Terminal header | 28px | 24px |
| Sidebar width | 220px | 232px |
| Sidebar item padding | mixed 5-8px | 8px vertical, 12px horizontal |
| Quick launch button padding | mixed | 8px x 12px |
| Section gaps | mixed 12-16px | 16px consistently |
| Border radius | mixed 4-6-8px | 6px everywhere |
| Divider thickness | 1px | 0.5px hairline |

## 3. Animations

| Interaction | Animation | Duration | Curve |
|-------------|-----------|----------|-------|
| Hover on sidebar item | Background fade in | 120ms | easeOut |
| Hover on preset button | Brightness lift + scale(1.02) | 150ms | easeOut |
| Tab switch | Active indicator slides horizontally | 200ms | easeInOut |
| Overlay open | Fade in + slide down 8px | 200ms | easeOut |
| Overlay close | Fade out | 150ms | easeIn |
| Status dot (active terminal) | Pulse opacity 0.6→1.0 loop | 2000ms | easeInOut |
| Terminal focus | Thin blue outline fade in | 150ms | easeOut |
| Sidebar resize | Spring physics on release | 300ms | spring |
| Context menu appear | Fade in + scale from 0.95 | 120ms | easeOut |

**Do NOT animate:** Terminal content rendering, keystroke echoing, file tree expand/collapse.

## 4. Micro-details

### Tabs
- Active tab: 2px blue bottom border + slightly lighter background
- Inactive tabs: no background, text only. Hover: subtle background fade
- Badge: pill-shaped, 12px height, 6px horizontal padding, rounded-full

### Preset Buttons
- Hover: left color border glows (box-shadow with preset color at 30% opacity)
- Press: scale down to 0.98 for 50ms

### Terminal List Items
- Active: 2px left accent bar (blue) instead of just background highlight
- Status dot: 6px diameter. Active terminal dot pulses gently

### Scrollbars
- 4px thin, rounded, only visible on hover
- Track: transparent. Thumb: white at 20% opacity

### Overlays (settings, command palette, shortcuts)
- Backdrop: blur(4px) + black at 40% opacity
- Panel: drop shadow (0 8px 32px rgba(0,0,0,0.5))

### Welcome Screen
- "Dispatch" title with subtle gradient text (blue → white)
- Open Folder button: hover glow effect

## 5. Out of Scope

- Layout structure (sidebar + terminal area + tab bar stays the same)
- Color palette (keep existing colors)
- New components (no toasts, tooltips, loading skeletons)
- Feature behavior (everything works the same)
- Terminal rendering (xterm package untouched)

## Files to Modify

- `lib/src/core/theme/app_theme.dart` — add animation constants, spacing constants, typography presets
- `lib/src/features/projects/tab_bar.dart` — tighter height, pill badges, hover animations
- `lib/src/features/sidebar/sidebar.dart` — updated width, hairline borders
- `lib/src/features/sidebar/terminal_list.dart` — active accent bar, dot pulse, hover fade
- `lib/src/features/presets/quick_launch.dart` — hover glow, press scale
- `lib/src/features/terminal/terminal_pane.dart` — thinner header, focus ring
- `lib/src/features/terminal/terminal_area.dart` — sub-tab spacing
- `lib/src/features/command_palette/command_palette.dart` — overlay blur + shadow + slide animation
- `lib/src/features/command_palette/quick_switcher.dart` — same overlay treatment
- `lib/src/features/settings/settings_panel.dart` — same overlay treatment
- `lib/src/features/shortcuts/shortcuts_panel.dart` — same overlay treatment
- `lib/src/features/projects/welcome_screen.dart` — gradient title, button glow
- `lib/src/features/notes/notes_panel.dart` — consistent spacing
- `lib/src/features/tasks/tasks_panel.dart` — consistent spacing
- `lib/src/features/vault/vault_panel.dart` — consistent spacing
- `lib/src/features/projects/project_panel.dart` — tab styling consistency
- `lib/src/features/sidebar/file_tree.dart` — consistent spacing
- `lib/src/features/browser/browser_panel.dart` — consistent spacing
- `lib/src/features/browser/browser_console.dart` — consistent spacing
- `lib/src/features/terminal/save_template_dialog.dart` — overlay treatment
