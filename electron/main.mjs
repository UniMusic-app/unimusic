import { app, BrowserWindow, ipcMain } from "electron";
import path from "path";
import { fileURLToPath } from "url";
import electronServe from "electron-serve";
import { authorizeMusicKit } from "./musickit/auth.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const loadUrl = electronServe({
	directory: "../dist",
});

let mainWindow;
function createWindow() {
	mainWindow = new BrowserWindow({
		width: 800,
		height: 650,
		minHeight: 650,
		minWidth: 200,
		webPreferences: {
			preload: path.join(__dirname, "preload.mjs"),
			nodeIntegration: false,
			contextIsolation: true,
		},
	});
	loadUrl(mainWindow);
}

app.whenReady().then(() => {
	createWindow();

	ipcMain.handle("musickit:authorize", authorizeMusicKit);

	app.on("activate", () => {
		if (BrowserWindow.getAllWindows().length === 0) createWindow();
	});
});

app.on("window-all-closed", () => {
	if (process.platform !== "darwin") app.quit();
});
