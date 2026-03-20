# Dispatch

A desktop terminal manager for Claude Code power users. Groups terminals by project, provides quick-launch presets, detects and attaches to external terminal sessions, and offers full keyboard + mouse navigation.

## Features

- **Project-grouped terminals** — All terminals in one window, organized by project
- **Quick-launch presets** — One-click commands to spin up Claude Code sessions
- **External terminal detection** — Detects and adopts terminals from other apps via tmux
- **Split panes** — Horizontal (`Cmd+D`) and vertical (`Cmd+Shift+D`) splits
- **Session templates** — Save and restore terminal layouts
- **Built-in browser panel** — Preview localhost URLs with console capture
- **Notes, Tasks & Vault** — Per-project notes, task tracking, and encrypted secrets storage
- **Keyboard-first navigation** — Full keyboard and mouse support

## Tech Stack

- **Electron** — Desktop shell
- **React + Zustand** — Renderer UI and state management
- **xterm.js** — Terminal emulation
- **node-pty** — PTY backend
- **TypeScript** — End to end
- **Webpack** — Bundling
- **Vitest** — Testing

## Getting Started

### Prerequisites

- Node.js (v18+)
- npm

### Install

```bash
npm install
```

### Development

```bash
# Start renderer dev server
npm run dev:renderer

# In another terminal, build and watch main process
npm run dev:main

# Launch the app
npm start
```

### Build

```bash
# Production build
npm run build

# Package as distributable
npm run package
```

### Test

```bash
npm test
```

## Platform Support

macOS and Linux.

## License

[ISC](LICENSE)
