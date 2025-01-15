// eslint-disable-next-line @typescript-eslint/no-var-requires
const { contextBridge, ipcRenderer } = require("electron/renderer");

contextBridge.exposeInMainWorld("ElectronMusicPlayer", {
	authorizeMusicKit: () => ipcRenderer.invoke("musickit:authorize"),
});
