import { useIDBKeyval } from "@vueuse/integrations/useIDBKeyval.mjs";
import { defineStore } from "pinia";

import UniMusicSync, { DocTicket, Entry, NamespaceId } from "@/plugins/UniMusicSync";
import { getPlatform } from "@/utils/os";
import { audioMimeTypeFromPath, traverseDirectory } from "@/utils/path";
import { Directory, Filesystem } from "@capacitor/filesystem";

type Path = string;

interface FileInfo {
	mtime: number;
	size: number;
	entry?: Entry;
}

interface DirectoryInfo {
	lastRecordedInfo?: Record<Path, FileInfo>;
}

export interface SyncData {
	watchedDirectories: Record<Path, DirectoryInfo>;
	namespaces: NamespaceId[];
}

export const useSync = defineStore("UniMusicSync", () => {
	const synchronizationData = useIDBKeyval<SyncData>("uniMusicSync", {
		watchedDirectories: {},
		namespaces: [],
	});

	function log(...args: unknown[]): void {
		console.debug("%UniMusicSync:", "color: #9f00ff; font-weight: bold;", ...args);
	}

	function syncData(): SyncData {
		return synchronizationData.data.value;
	}

	async function syncDirectory(relativePath: string): Promise<void> {
		log(`Synchronizing ${relativePath}`);

		log(`- Reconnecting`);
		await UniMusicSync.reconnect();

		const syncData = synchronizationData.data.value;

		if (!syncData.namespaces.length) {
			const { namespace } = await UniMusicSync.createNamespace();
			syncData.namespaces.push(namespace);
		}

		const recordedInfo: Record<Path, FileInfo> = {};

		for (const namespace of syncData.namespaces) {
			log(`- Sync namespace ${namespace}`);

			await UniMusicSync.sync({ namespace });
			const syncedFiles = await UniMusicSync.getFiles({ namespace });

			let path: string;
			switch (getPlatform()) {
				case "android":
					throw new Error("todo");
				case "electron": {
					const musicPath = await ElectronMusicPlayer!.getMusicPath();

					path = musicPath;
					if (relativePath.startsWith("./")) {
						path += relativePath.slice(2);
					} else if (relativePath.startsWith("/")) {
						path += relativePath.slice();
					} else {
						path += relativePath;
					}
					break;
				}
				case "ios":
					path = relativePath;
					break;
				case "web":
					return;
			}

			const watchedDirectory = syncData.watchedDirectories[relativePath];

			const lastRecordedInfo = watchedDirectory?.lastRecordedInfo;
			for await (const { filePath } of traverseDirectory(path)) {
				if (!audioMimeTypeFromPath(filePath)) continue;
				log(`- Sync file ${filePath}`);

				const syncPath = filePath.replace("//", "/").replaceAll("\\", "/");
				const lastFileInfo = lastRecordedInfo?.[syncPath];

				let sourcePath: string;
				let mtime: number;
				let size: number;
				switch (getPlatform()) {
					case "electron": {
						throw new Error("todo");
					}
					case "android": {
						sourcePath = filePath;
						const stat = await Filesystem.stat({
							path: filePath,
						});
						mtime = stat.mtime;
						size = stat.size;
						break;
					}
					case "ios": {
						const stat = await Filesystem.stat({
							path: filePath,
							directory: Directory.Documents,
						});
						sourcePath = stat.uri;
						mtime = stat.mtime;
						size = stat.size;
						break;
					}
					default:
						throw new Error("unreachable");
				}

				const entry = syncedFiles[syncPath];

				if (!entry || !lastFileInfo) {
					log(`Updating ${syncPath} (New local entry)`);
					await UniMusicSync.writeFile({ namespace, sourcePath, syncPath });
				} else if (lastFileInfo?.entry && entry.contentHash !== lastFileInfo.entry.contentHash) {
					log(`Updating ${syncPath} (New remote value | EXPORT)`);
					await UniMusicSync.exportHash({
						fileHash: entry.contentHash,
						destination: sourcePath,
					});
				} else if (lastFileInfo.mtime !== mtime || lastFileInfo.size !== size) {
					log(`Updating ${syncPath} (File got modified)`);
					await UniMusicSync.writeFile({ namespace, sourcePath, syncPath });
				} else {
					log(`File ${syncPath} already up to date`);
				}

				recordedInfo[syncPath] = { mtime, size, entry };
			}

			const seenFiles = new Set(Object.keys(recordedInfo));
			const allFiles = new Set(Object.keys(syncedFiles));

			for (const syncPath of allFiles.difference(seenFiles)) {
				const { uri } = await Filesystem.getUri({
					path: syncPath,
					directory: Directory.Documents,
				});

				const destination = uri.replace("file://", "");
				log(`Retrieving ${syncPath} (Missing locally, saving to ${destination})`);

				await UniMusicSync.export({
					namespace,
					syncPath,
					destination,
				});
			}
		}

		syncData.watchedDirectories[relativePath] = { lastRecordedInfo: recordedInfo };
	}

	async function shareSongs(): Promise<DocTicket[]> {
		const syncData = synchronizationData.data.value;

		const tickets = [];
		for (const namespace of syncData.namespaces) {
			log(`Share namespace ${namespace}`);
			const { ticket } = await UniMusicSync.share({ namespace });
			log(`Share namespace ${namespace} -> ${ticket}`);
			tickets.push(ticket);
		}

		return tickets;
	}

	async function importSongs(tickets: DocTicket[]): Promise<void> {
		const syncData = synchronizationData.data.value;

		for (const ticket of tickets) {
			log(`Importing ticket ${ticket}`);
			const { namespace } = await UniMusicSync.import({ ticket });

			if (syncData.namespaces.includes(namespace)) {
				log(`Namespace ${namespace} was already imported`);
			} else {
				syncData.namespaces.push(namespace);
				log(`Imported namespace ${namespace}`);
			}
		}
	}

	return {
		syncData,
		syncDirectory,
		shareSongs,
		importSongs,
	};
});
