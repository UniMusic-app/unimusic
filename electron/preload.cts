// @ts-expect-error electron/renderer types missing
import { contextBridge, ipcRenderer } from "electron/renderer";

contextBridge.exposeInMainWorld("ElectronMusicPlayer", {
	authorizeMusicKit: () => ipcRenderer.invoke("musickit:authorize"),
});
