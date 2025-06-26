import { contextBridge, ipcRenderer } from "electron/renderer";

contextBridge.exposeInMainWorld("$ElectronBridge", {
	musicKit: {
		authorize: () => ipcRenderer.invoke("musickit:authorize"),
	},

	fetch: (input, init) => ipcRenderer.invoke("web:fetch", input, init),

	fileSystem: {
		readFile: (path) => ipcRenderer.invoke("fs:read_file", path),
		writeFile: (path, buffer) => ipcRenderer.invoke("fs:write_file", path, buffer),
		statFile: (path) => ipcRenderer.invoke("fs:stat_file", path),
		getMusicPath: () => ipcRenderer.invoke("fs:music_path"),
		getUserDataPath: () => ipcRenderer.invoke("fs:user_data_path"),
		pickDirectory: () => ipcRenderer.invoke("fs:pick_directory"),
		traverseDirectory: (path) => ipcRenderer.invoke("fs:traverse_dir", path),
	},

	uniMusicSync: {
		initialize: () => ipcRenderer.invoke("unimusicsync:initialize"),
		createNamespace: () => ipcRenderer.invoke("unimusicsync:create_namespace"),
		deleteNamespace: (namespace) => ipcRenderer.invoke("unimusicsync:delete_namespace", namespace),
		getAuthor: () => ipcRenderer.invoke("unimusicsync:get_author"),
		getNodeId: () => ipcRenderer.invoke("unimusicsync:get_node_id"),
		getFiles: (namespace) => ipcRenderer.invoke("unimusicsync:get_files", namespace),
		writeFile: (namespace, syncPath, sourcePath) =>
			ipcRenderer.invoke("unimusicsync:write_file", namespace, syncPath, sourcePath),
		deleteFile: (namespace, syncPath) =>
			ipcRenderer.invoke("unimusicsync:delete_file", namespace, syncPath),
		readFile: (namespace, syncPath) =>
			ipcRenderer.invoke("unimusicsync:read_file", namespace, syncPath),
		readFileHash: (fileHash) => ipcRenderer.invoke("unimusicsync:read_file_hash", fileHash),
		export: (namespace, syncPath, destinationPath) =>
			ipcRenderer.invoke("unimusicsync:export", namespace, syncPath, destinationPath),
		exportHash: (fileHash, destinationPath) =>
			ipcRenderer.invoke("unimusicsync:export_hash", fileHash, destinationPath),
		share: (namespace) => ipcRenderer.invoke("unimusicsync:share", namespace),
		import: (ticket) => ipcRenderer.invoke("unimusicsync:import", ticket),
		sync: (namespace) => ipcRenderer.invoke("unimusicsync:sync", namespace),
		reconnect: () => ipcRenderer.invoke("unimusicsync:reconnect"),
	},
});
