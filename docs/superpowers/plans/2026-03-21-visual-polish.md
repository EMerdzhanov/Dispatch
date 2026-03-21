# Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply a visual refinement pass to all Dispatch Flutter widgets — tighter typography, consistent spacing, smooth animations, and micro-details — to achieve IDE-grade polish.

**Architecture:** Update the centralized `AppTheme` with animation/spacing constants, then sweep through every widget file applying the new system. No layout changes, no new features, no new components.

**Tech Stack:** Flutter, existing widget tree

**Spec:** `docs/superpowers/specs/2026-03-21-visual-polish-design.md`

---

## File Structure

All files are modifications to existing code in `packages/dispatch_app/lib/src/`:

```
core/theme/app_theme.dart              — Add animation durations, spacing constants, text styles
features/projects/tab_bar.dart         — Tighter height, pill badges, hover animations
features/projects/welcome_screen.dart  — Gradient title, button glow
features/sidebar/sidebar.dart          — Updated width, hairline borders
features/sidebar/terminal_list.dart    — Active accent bar, dot pulse, hover fade
features/sidebar/file_tree.dart        — Consistent spacing
features/sidebar/status_bar.dart       — Consistent spacing
features/presets/quick_launch.dart     — Hover glow, press scale
features/terminal/terminal_pane.dart   — Thinner header, focus ring
features/terminal/terminal_area.dart   — Sub-tab spacing
features/terminal/split_container.dart — Consistent border radius
features/terminal/save_template_dialog.dart — Overlay blur + shadow
features/command_palette/command_palette.dart — Overlay blur + shadow + slide
features/command_palette/quick_switcher.dart  — Same overlay treatment
features/settings/settings_panel.dart  — Same overlay treatment
features/shortcuts/shortcuts_panel.dart — Same overlay treatment
features/notes/notes_panel.dart        — Consistent spacing
features/tasks/tasks_panel.dart        — Consistent spacing
features/vault/vault_panel.dart        — Consistent spacing
features/projects/project_panel.dart   — Tab styling
features/browser/browser_panel.dart    — Consistent spacing
features/browser/browser_console.dart  — Consistent spacing
```

---

### Task 1: Theme Constants & Text Styles

**Files:**
- Modify: `packages/dispatch_app/lib/src/core/theme/app_theme.dart`

- [ ] **Step 1: Add animation duration constants**

```dart
// Add to AppTheme class:
static const hoverDuration = Duration(milliseconds: 120);
static const animDuration = Duration(milliseconds: 200);
static const animFastDuration = Duration(milliseconds: 150);
static const animCurve = Curves.easeOut;
static const animCurveIn = Curves.easeIn;
```

- [ ] **Step 2: Add spacing constants**

```dart
static const double spacingXs = 4;
static const double spacingSm = 8;
static const double spacingMd = 12;
static const double spacingLg = 16;
static const double spacingXl = 24;
static const double radius = 6;
static const double tabBarHeight = 32;
static const double terminalHeaderHeight = 24;
static const double sidebarWidth = 240;
static const double borderWidth = 0.5;
```

- [ ] **Step 3: Add text style presets**

```dart
static const labelStyle = TextStyle(
  color: textSecondary,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.8,
);

static const bodyStyle = TextStyle(
  color: textPrimary,
  fontSize: 12,
  fontWeight: FontWeight.w400,
);

static const titleStyle = TextStyle(
  color: textPrimary,
  fontSize: 14,
  fontWeight: FontWeight.w500,
);

static const dimStyle = TextStyle(
  color: textSecondary,
  fontSize: 12,
  fontWeight: FontWeight.w400,
);
```

- [ ] **Step 4: Add overlay decoration helper**

```dart
static BoxDecoration get overlayDecoration => BoxDecoration(
  color: surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: border, width: borderWidth),
  boxShadow: const [
    BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 8)),
  ],
);
```

- [ ] **Step 5: Verify analysis passes**

Run: `cd packages/dispatch_app && dart analyze lib/src/core/theme/app_theme.dart`

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(theme): add animation, spacing, and typography constants"
```

---

### Task 2: Tab Bar Polish

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/projects/tab_bar.dart`

- [ ] **Step 1: Apply new constants**

Replace all hardcoded values:
- Tab bar height: use `AppTheme.tabBarHeight` (32px)
- Border radius: use `AppTheme.radius` (6px)
- Padding: use `AppTheme.spacingSm` / `AppTheme.spacingMd`
- Font sizes: section labels 10px uppercase w600, tab names 12px w400
- Border width: `AppTheme.borderWidth` (0.5px)
- Badge: pill-shaped with `BorderRadius.circular(12)`, height 16px, horizontal padding 6px, fontSize 9px w500

- [ ] **Step 2: Add hover animation to tabs**

Wrap each tab in `AnimatedContainer` with `duration: AppTheme.hoverDuration` and `curve: AppTheme.animCurve`. On hover (via `MouseRegion`), fade background to `AppTheme.surfaceLight.withOpacity(0.5)`.

- [ ] **Step 3: Animate active tab indicator**

Use `AnimatedContainer` for the bottom border so the blue accent slides when switching tabs.

- [ ] **Step 4: Verify analysis and commit**

```bash
dart analyze lib/src/features/projects/tab_bar.dart
git commit -m "polish(tab-bar): tighter height, pill badges, hover animations"
```

---

### Task 3: Sidebar & Terminal List Polish

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/sidebar/sidebar.dart`
- Modify: `packages/dispatch_app/lib/src/features/sidebar/terminal_list.dart`
- Modify: `packages/dispatch_app/lib/src/features/sidebar/status_bar.dart`
- Modify: `packages/dispatch_app/lib/src/features/sidebar/file_tree.dart`

- [ ] **Step 1: Sidebar width and borders**

- Width: `AppTheme.sidebarWidth` (240px)
- Border: `AppTheme.borderWidth` (0.5px)
- All internal dividers: 0.5px

- [ ] **Step 2: Terminal list — active accent bar**

For the active terminal item, add a 2px wide blue bar on the left edge instead of just a background change:

```dart
Container(
  decoration: BoxDecoration(
    border: Border(
      left: BorderSide(
        color: isActive ? AppTheme.accentBlue : Colors.transparent,
        width: 2,
      ),
    ),
  ),
)
```

- [ ] **Step 3: Status dot pulse animation**

For the active terminal's status dot, wrap in `AnimatedOpacity` or use a repeating `AnimationController` that pulses opacity between 0.6 and 1.0 over 2 seconds:

```dart
// In _TerminalListItemState, add:
late AnimationController _pulseController;
late Animation<double> _pulseAnimation;

@override
void initState() {
  super.initState();
  if (widget.isActive) {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
}
```

- [ ] **Step 4: Section labels uppercase**

In terminal_list.dart, the TERMINALS / FILES tab labels should use `AppTheme.labelStyle` (10px, w600, 0.8px tracking, uppercase).

- [ ] **Step 5: File tree consistent spacing**

Item padding: `EdgeInsets.only(left: 8.0 + depth * 14, top: 4, bottom: 4, right: 8)` — consistent 4px vertical.

- [ ] **Step 6: Status bar consistent spacing**

Use `AppTheme.spacingSm` for padding. Font: `AppTheme.dimStyle`.

- [ ] **Step 7: Verify and commit**

```bash
dart analyze lib/src/features/sidebar/
git commit -m "polish(sidebar): accent bar, dot pulse, uppercase labels, hairline borders"
```

---

### Task 4: Quick Launch Polish

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/presets/quick_launch.dart`

- [ ] **Step 1: "QUICK LAUNCH" label**

Use `AppTheme.labelStyle` — 10px, w600, 0.8px tracking, uppercase.

- [ ] **Step 2: Button hover glow**

On hover, add a `BoxShadow` using the preset's color at 30% opacity:

```dart
boxShadow: isHovered ? [
  BoxShadow(color: presetColor.withOpacity(0.3), blurRadius: 8, spreadRadius: -2),
] : null,
```

- [ ] **Step 3: Button press scale**

Wrap button in `AnimatedScale`:
```dart
AnimatedScale(
  scale: isPressed ? 0.98 : 1.0,
  duration: const Duration(milliseconds: 50),
  child: ...
)
```

Use `GestureDetector.onTapDown` / `onTapUp` to toggle `isPressed`.

- [ ] **Step 4: Consistent padding**

Button padding: 8px vertical, 12px horizontal. Border radius: `AppTheme.radius`.

- [ ] **Step 5: Verify and commit**

```bash
git commit -m "polish(presets): hover glow, press scale, uppercase label"
```

---

### Task 5: Terminal Pane & Area Polish

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/terminal/terminal_pane.dart`
- Modify: `packages/dispatch_app/lib/src/features/terminal/terminal_area.dart`
- Modify: `packages/dispatch_app/lib/src/features/terminal/split_container.dart`

- [ ] **Step 1: Terminal header height**

Reduce from 28px to `AppTheme.terminalHeaderHeight` (24px). Font size for header label: 11px → 10px.

- [ ] **Step 2: Terminal focus ring**

When the terminal has focus, show a thin blue outline around the terminal area:

```dart
Container(
  decoration: BoxDecoration(
    border: Border.all(
      color: hasFocus ? AppTheme.accentBlue.withOpacity(0.5) : Colors.transparent,
      width: 1,
    ),
  ),
)
```

- [ ] **Step 3: Sub-tab bar spacing**

Use `AppTheme.spacingMd` for horizontal padding. Font: 11px → use `AppTheme.bodyStyle` at 11px.

- [ ] **Step 4: Split container border radius**

Divider: use `AppTheme.borderWidth` (0.5px). Consistent with sidebar dividers.

- [ ] **Step 5: Verify and commit**

```bash
git commit -m "polish(terminal): thinner header, focus ring, consistent spacing"
```

---

### Task 6: Overlay Polish (All Overlays)

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/command_palette/command_palette.dart`
- Modify: `packages/dispatch_app/lib/src/features/command_palette/quick_switcher.dart`
- Modify: `packages/dispatch_app/lib/src/features/settings/settings_panel.dart`
- Modify: `packages/dispatch_app/lib/src/features/shortcuts/shortcuts_panel.dart`
- Modify: `packages/dispatch_app/lib/src/features/terminal/save_template_dialog.dart`

- [ ] **Step 1: Backdrop blur**

Replace `Colors.black54` backdrop with:

```dart
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
  child: Container(color: Colors.black.withOpacity(0.4)),
)
```

Import `dart:ui` for `ImageFilter`.

- [ ] **Step 2: Panel shadow**

Use `AppTheme.overlayDecoration` for the panel Material:

```dart
Material(
  color: Colors.transparent,
  child: Container(
    decoration: AppTheme.overlayDecoration,
    child: ...
  ),
)
```

- [ ] **Step 3: Slide-in animation**

Wrap the panel in `AnimatedSlide` + `AnimatedOpacity`:

```dart
AnimatedSlide(
  offset: Offset(0, widget.open ? 0 : -0.02),
  duration: AppTheme.animDuration,
  curve: AppTheme.animCurve,
  child: AnimatedOpacity(
    opacity: widget.open ? 1.0 : 0.0,
    duration: AppTheme.animFastDuration,
    child: panel,
  ),
)
```

- [ ] **Step 4: Consistent font sizes in all overlays**

- Panel title: `AppTheme.titleStyle` (14px, w500)
- Input text: 12px w400
- Result items: 12px w400
- Sublabels: 10px, textSecondary
- Border radius: `AppTheme.radius` everywhere

- [ ] **Step 5: Apply to all 5 overlay files**

Same treatment for command_palette, quick_switcher, settings_panel, shortcuts_panel, save_template_dialog.

- [ ] **Step 6: Verify and commit**

```bash
dart analyze lib/src/features/
git commit -m "polish(overlays): backdrop blur, shadow, slide animation, consistent fonts"
```

---

### Task 7: Welcome Screen & Project Panel Polish

**Files:**
- Modify: `packages/dispatch_app/lib/src/features/projects/welcome_screen.dart`
- Modify: `packages/dispatch_app/lib/src/features/projects/project_panel.dart`
- Modify: `packages/dispatch_app/lib/src/features/notes/notes_panel.dart`
- Modify: `packages/dispatch_app/lib/src/features/tasks/tasks_panel.dart`
- Modify: `packages/dispatch_app/lib/src/features/vault/vault_panel.dart`
- Modify: `packages/dispatch_app/lib/src/features/browser/browser_panel.dart`
- Modify: `packages/dispatch_app/lib/src/features/browser/browser_console.dart`

- [ ] **Step 1: Welcome screen gradient title**

```dart
ShaderMask(
  shaderCallback: (bounds) => const LinearGradient(
    colors: [AppTheme.accentBlue, Colors.white],
  ).createShader(bounds),
  child: const Text('Dispatch', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: Colors.white)),
)
```

- [ ] **Step 2: Open Folder button hover glow**

On hover, add blue glow:
```dart
boxShadow: isHovered ? [
  BoxShadow(color: AppTheme.accentBlue.withOpacity(0.4), blurRadius: 16, spreadRadius: -4),
] : null,
```

- [ ] **Step 3: Project panel tab styling**

Tab labels: use `AppTheme.labelStyle` when inactive, add active underline. Consistent `AppTheme.spacingSm` padding.

- [ ] **Step 4: Notes/Tasks/Vault consistent spacing**

All panels: item padding `AppTheme.spacingSm` vertical, `AppTheme.spacingMd` horizontal. Font sizes snap to 10/12/14. Dividers 0.5px.

- [ ] **Step 5: Browser panel & console consistent spacing**

URL bar: use `AppTheme.spacingSm` padding. Console toggle: 12px font. Consistent with rest of app.

- [ ] **Step 6: Verify full app and commit**

```bash
dart analyze lib/
git commit -m "polish(screens): gradient title, button glow, consistent panel spacing"
```

---

### Task 8: Final Sweep & Build Verification

- [ ] **Step 1: Run full analysis**

```bash
cd packages/dispatch_app && dart analyze lib/
```
Expected: No errors.

- [ ] **Step 2: Build and launch**

```bash
flutter build macos --debug
open build/macos/Build/Products/Debug/dispatch_app.app
```

- [ ] **Step 3: Visual verification checklist**

- [ ] Tab bar is 32px height with pill badges
- [ ] Hover animations on tabs, preset buttons, sidebar items
- [ ] Active terminal has blue left accent bar
- [ ] Active terminal dot pulses
- [ ] Overlay backdrop has blur effect
- [ ] Overlays have drop shadow and slide-in animation
- [ ] Section labels are uppercase with letter-spacing
- [ ] All borders are 0.5px hairline
- [ ] Welcome screen has gradient title and button glow
- [ ] All font sizes are 10, 12, or 14px — no others

- [ ] **Step 4: Commit any fixes**

```bash
git commit -m "polish: final sweep fixes"
```

---

## Summary

| Task | Scope | Commit |
|------|-------|--------|
| 1 | Theme constants (animation, spacing, text styles) | `feat(theme)` |
| 2 | Tab bar (height, badges, hover, active indicator) | `polish(tab-bar)` |
| 3 | Sidebar (accent bar, dot pulse, labels, borders) | `polish(sidebar)` |
| 4 | Quick launch (hover glow, press scale, label) | `polish(presets)` |
| 5 | Terminal (thinner header, focus ring, spacing) | `polish(terminal)` |
| 6 | All overlays (blur, shadow, slide, fonts) | `polish(overlays)` |
| 7 | Welcome, panels, browser (gradient, spacing) | `polish(screens)` |
| 8 | Final sweep and build verification | `polish: final` |
