import { app, BrowserWindow, ipcMain } from 'electron';
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
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#0a0a1a',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (process.env.NODE_ENV === 'development') {
    mainWindow.loadURL('http://localhost:8080');
  } else {
    mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
  }
}

app.whenReady().then(() => {
  registerIpc(ptyManager, store);

  // app:homedir handler
  ipcMain.handle('app:homedir', () => os.homedir());

  createWindow();
});

app.on('window-all-closed', () => {
  ptyManager.killAll();
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
