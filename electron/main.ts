import { app, BrowserWindow, components, dialog, ipcMain, net, protocol } from "electron";
import electronServe from "electron-serve";

import { URLPattern } from "urlpattern-polyfill";

import fs from "node:fs/promises";
import { dirname, join, normalize } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { addon as uniMusicSync } from "@unimusic/sync";
import { authorizeMusicKit } from "./musickit/auth";

const ALLOWED_URLS = [
	"local-images:",
	// MusicKit
	"https://*.apple.com",
	// YouTube
	"https://youtube.com",
	"https://*.youtube.com",
	"https://*.googlevideo.com",
	"https://*.googleapis.com",
	"https://*.googleusercontent.com",
	"https://*.mzstatic.com",
	"https://*.ytimg.com",
	// Song Lyrics
	"https://lrclib.net",
	// Music Metadata
	"https://musicbrainz.org",
	"https://api.acoustid.org",
	"http://coverartarchive.org",
	"https://coverartarchive.org",
	"http://archive.org",
	"https://archive.org",
	"https://*.archive.org",
];
const ALLOWED_URL_PATTERNS = ALLOWED_URLS.map((url) => new URLPattern(url));

const urlScheme = "unimusic";
const loadUrl = electronServe({
	directory: fileURLToPath(new URL("../renderer/", import.meta.url)),
	scheme: urlScheme,
});

let mainWindow;
async function createWindow(): Promise<void> {
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

	const { session } = mainWindow.webContents;

	session.webRequest.onHeadersReceived((details, callback) => {
		const CSP = `
		default-src 'self' blob: data: 'unsafe-inline' 'unsafe-eval' ${ALLOWED_URLS.join(" ")};
		img-src 'self' blob: data: local-images: *;
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

app.on("activate", async () => {
	if (BrowserWindow.getAllWindows().length === 0) {
		await createWindow();
	}
});

app.on("window-all-closed", () => {
	if (process.platform !== "darwin") app.quit();
});

protocol.registerSchemesAsPrivileged([
	{ scheme: "local-images", privileges: { standard: true, supportFetchAPI: true } },
	{ scheme: "unimusic", privileges: { standard: true, supportFetchAPI: true } },
]);

void app.whenReady().then(async () => {
	// This allows us to safely fetch, put and delete local images from userData/LocalImages folder
	// by calling local-images protocol, e.g. local-images://abcdefg-large
	protocol.handle("local-images", async (request): Promise<Response> => {
		const imageUrl = new URL(request.url);

		const imagesPath = join(app.getPath("userData"), "LocalImages");
		const targetPath = normalize(join(imagesPath, imageUrl.hostname));

		if (!targetPath.startsWith(imagesPath)) {
			return Response.json(
				{ error: "Tried to access file out of LocalImages directory" },
				{ status: 403 },
			);
		}

		switch (request.method) {
			case "GET": {
				const targetUrl = pathToFileURL(targetPath);
				return net.fetch(targetUrl.toString());
			}
			case "PUT": {
				try {
					const formData = await request.formData();
					const image = formData.get("image");

					if (!image) {
						return Response.json({ error: "FormData entry 'image' is missing" }, { status: 400 });
					} else if (!(image instanceof Blob)) {
						return Response.json({ error: "FormData entry 'image' must be a Blob" }, { status: 400 });
					}

					const imageBuffer = new Uint8Array(await image.arrayBuffer());

					await fs.mkdir(dirname(targetPath), { recursive: true });
					await fs.writeFile(targetPath, imageBuffer);

					return Response.json({}, { status: 200 });
				} catch (error) {
					return Response.json(
						{ error: error instanceof Error ? error.message : String(error) },
						{ status: 500 },
					);
				}
			}
			case "DELETE": {
				try {
					await fs.unlink(targetPath);
					return Response.json({}, { status: 200 });
				} catch (error) {
					return Response.json(
						{ error: error instanceof Error ? error.message : String(error) },
						{ status: 500 },
					);
				}
			}
			default:
				return Response.json({ error: "Unsupported method" }, { status: 405 });
		}
	});

	ipcMain.handle("musickit:authorize", () => authorizeMusicKit());

	//#region Web
	ipcMain.handle("web:fetch", async (_, input, init) => {
		if (typeof input !== "string" || ALLOWED_URL_PATTERNS.every((pattern) => !pattern.test(input))) {
			return Promise.reject(`URL not allowed: ${input}`);
		}

		try {
			const response = await fetch(input, init);
			return {
				url: response.url,
				status: response.status,
				statusText: response.statusText,
				body: await response.bytes(),
				headers: Object.fromEntries(response.headers.entries()),
			};
		} catch (error) {
			return Promise.reject(error);
		}
	});
	//#endregion

	//#region Filesystem
	ipcMain.handle("fs:music_path", () => app.getPath("music"));
	ipcMain.handle("fs:user_data_path", () => app.getPath("userData"));
	ipcMain.handle("fs:read_file", async (_, path: string): Promise<Uint8Array> => {
		return await fs.readFile(path);
	});
	ipcMain.handle("fs:write_file", async (_, path: string, file: Uint8Array): Promise<void> => {
		await fs.mkdir(dirname(path), { recursive: true });
		await fs.writeFile(path, file);
	});

	type FileStat = { type: "file" | "directory"; mtime: number; ctime: number; size: number };
	ipcMain.handle("fs:stat_file", async (_, path: string): Promise<FileStat> => {
		const stat = await fs.stat(path);
		return {
			type: stat.isDirectory() ? "directory" : "file",
			size: stat.size,
			ctime: stat.ctimeMs,
			mtime: stat.mtimeMs,
		};
	});

	ipcMain.handle("fs:pick_directory", async (_): Promise<string> => {
		const result = await dialog.showOpenDialog({
			properties: ["openDirectory"],
			title: "Select a folder",
			defaultPath: app.getPath("music") ?? process.env.HOME,
			buttonLabel: "Choose folder",
		});

		if (!result.canceled && result.filePaths.length > 0) {
			const [selectedPath] = result.filePaths;
			return selectedPath;
		}

		throw new Error("User did not pick a directory");
	});
	ipcMain.handle("fs:traverse_dir", async (_, path: string): Promise<string[]> => {
		const directories = [path];
		const filePaths = [];

		while (directories.length > 0) {
			const directory = directories.pop()!;
			const entries = await fs.readdir(directory, { withFileTypes: true }).catch((error) => {
				console.error(`Failed to access ${directory}:`, error);
				return [];
			});

			for (const entry of entries) {
				const absolutePath = join(entry.parentPath, entry.name);

				if (entry.isDirectory()) {
					directories.push(absolutePath);
				} else {
					filePaths.push(absolutePath);
				}
			}
		}

		return filePaths;
	});
	//#endregion

	//#region UniMusicSync
	ipcMain.handle("unimusicsync:initialize", async () => {
		const path = join(app.getPath("userData"), "UniMusicSync");
		await uniMusicSync.initialize(path);

		app.once("before-quit", async () => {
			await uniMusicSync.shutdown();
		});
	});

	ipcMain.handle("unimusicsync:create_namespace", async () => {
		const namespace = await uniMusicSync.createNamespace();
		return namespace;
	});

	ipcMain.handle("unimusicsync:delete_namespace", async (_, namespace) => {
		await uniMusicSync.deleteNamespace(namespace);
	});

	ipcMain.handle("unimusicsync:get_author", async () => {
		const author = await uniMusicSync.getAuthor();
		return author;
	});

	ipcMain.handle("unimusicsync:get_node_id", async () => {
		const nodeId = await uniMusicSync.getNodeId();
		return nodeId;
	});

	ipcMain.handle("unimusicsync:get_files", async (_, namespace) => {
		const files = await uniMusicSync.getFiles(namespace);
		return files;
	});

	ipcMain.handle("unimusicsync:write_file", async (_, namespace, syncPath, sourcePath) => {
		const fileHash = await uniMusicSync.writeFile(namespace, syncPath, sourcePath);
		return fileHash;
	});

	ipcMain.handle("unimusicsync:delete_file", async (_, namespace, syncPath) => {
		await uniMusicSync.deleteFile(namespace, syncPath);
	});

	ipcMain.handle("unimusicsync:read_file", async (_, namespace, syncPath) => {
		const data = await uniMusicSync.readFile(namespace, syncPath);
		return data;
	});

	ipcMain.handle("unimusicsync:read_file_hash", async (_, fileHash) => {
		const data = await uniMusicSync.readFileHash(fileHash);
		return data;
	});

	ipcMain.handle("unimusicsync:export", async (_, namespace, syncPath, destinationPath) => {
		await uniMusicSync.exportFile(namespace, syncPath, destinationPath);
	});

	ipcMain.handle("unimusicsync:export_hash", async (_, fileHash, destinationPath) => {
		await uniMusicSync.exportFileHash(fileHash, destinationPath);
	});

	ipcMain.handle("unimusicsync:share", async (_, namespace) => {
		const ticket = await uniMusicSync.share(namespace);
		return ticket;
	});

	ipcMain.handle("unimusicsync:import", async (_, ticket) => {
		const namespace = await uniMusicSync.importTicket(ticket);
		return namespace;
	});

	ipcMain.handle("unimusicsync:sync", async (_, namespace) => {
		await uniMusicSync.sync(namespace);
	});

	ipcMain.handle("unimusicsync:reconnect", async () => {
		await uniMusicSync.reconnect();
	});
	//#endregion

	await components.whenReady();
	await createWindow();
});
