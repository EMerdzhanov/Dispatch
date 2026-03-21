import { app, BrowserWindow, ipcMain, Menu } from 'electron';
import path from 'path';
import os from 'os';
import { PtyManager } from './pty-manager';
import { SessionStore } from './session-store';
import { registerIpc } from './ipc';

let mainWindow: BrowserWindow | null = null;

const ptyManager = new PtyManager();
const store = new SessionStore(
  path.join(app.getPath('home'), '.config', 'dispatch')
);

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    icon: path.join(__dirname, '../../build/icon.png'),
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#0a0a1a',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webviewTag: true,
    },
  });

  if (process.env.NODE_ENV === 'development') {
    mainWindow.loadURL('http://localhost:8080');
  } else {
    mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
  }

  // mainWindow.webContents.openDevTools({ mode: 'detach' });
}

app.commandLine.appendSwitch('autoplay-policy', 'no-user-gesture-required');

app.whenReady().then(() => {
  registerIpc(ptyManager, store);

  // app:homedir handler
  ipcMain.handle('app:homedir', () => os.homedir());

  // Custom menu: remove Cmd+R / Cmd+Shift+R reload shortcuts so they
  // don't accidentally kill all terminals. Pass them through to the
  // terminal instead (e.g. for browser hot-reload in localhost previews).
  const menu = Menu.buildFromTemplate([
    {
      label: app.name,
      submenu: [
        { role: 'about' },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideOthers' },
        { role: 'unhide' },
        { type: 'separator' },
        { role: 'quit' },
      ],
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' },
        { role: 'redo' },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'selectAll' },
      ],
    },
    {
      label: 'Window',
      submenu: [
        { role: 'minimize' },
        { role: 'zoom' },
        { role: 'close' },
        { type: 'separator' },
        { role: 'front' },
        { role: 'togglefullscreen' },
      ],
    },
  ]);
  Menu.setApplicationMenu(menu);

  createWindow();

  // Lock down webview security
  mainWindow!.webContents.on('will-attach-webview', (event, webPreferences, params) => {
    // Strip any dangerous preferences
    delete webPreferences.preload;
    delete (webPreferences as any).preloadURL;

    // Enforce security
    webPreferences.nodeIntegration = false;
    webPreferences.contextIsolation = true;
    webPreferences.sandbox = true;

    // Only allow localhost URLs
    const url = params.src || '';
    if (url && !url.match(/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?/)) {
      console.warn('Blocked non-localhost webview URL:', url);
      event.preventDefault();
    }
  });
});

app.on('window-all-closed', () => {
  ptyManager.killAll();
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
