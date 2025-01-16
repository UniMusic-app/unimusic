import { BrowserWindow, Cookie } from "electron";

export function authorizeMusicKit() {
	const authWindow = new BrowserWindow({
		width: 600,
		height: 600,
		title: "Apple Music Authorization",
		alwaysOnTop: true,
		resizable: false,
	});
	authWindow.loadURL("https://beta.music.apple.com/login");

	const { cookies } = authWindow.webContents.session;

	return new Promise((resolve, reject) => {
		const mediaUserTokenListener = (_event: unknown, cookie: Cookie) => {
			if (cookie.name === "media-user-token") {
				if (cookie.value) {
					resolve(cookie.value);
					console.log(cookie.value);
					authWindow.close();
				} else {
					reject("Could not get media-user-token value");
				}

				cookies.removeAllListeners();
			}
		};

		cookies.addListener("changed", mediaUserTokenListener);
	});
}
