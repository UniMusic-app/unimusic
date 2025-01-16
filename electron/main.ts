import { app, BrowserWindow, ipcMain } from "electron";
import electronServe from "electron-serve";
import { authorizeMusicKit } from "./musickit/auth.js";
import { fileURLToPath } from "url";

const loadUrl = electronServe({
	directory: fileURLToPath(new URL("../renderer/", import.meta.url)),
});

let mainWindow;
async function createWindow() {
	mainWindow = new BrowserWindow({
		width: 800,
		height: 650,
		minHeight: 650,
		minWidth: 200,
		webPreferences: {
			preload: fileURLToPath(new URL("../preload/preload.cjs", import.meta.url)),
			nodeIntegration: false,
			contextIsolation: true,
		},
	});

	mainWindow.webContents.session.webRequest.onHeadersReceived((details, callback) => {
		const CSP = `
		default-src 'self' blob: 'unsafe-inline' https://*.apple.com;
		img-src 'self' blob: *;
		`;

		callback({
			responseHeaders: {
				...details.responseHeaders,
				"Content-Security-Policy": [CSP],
			},
		});
	});

	await loadUrl(mainWindow);
}

app.whenReady().then(async () => {
	await createWindow();

	ipcMain.handle("musickit:authorize", () => authorizeMusicKit());

	app.on("activate", () => {
		if (BrowserWindow.getAllWindows().length === 0) createWindow();
	});
});

app.on("window-all-closed", () => {
	if (process.platform !== "darwin") app.quit();
});
