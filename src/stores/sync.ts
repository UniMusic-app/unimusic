import { useIDBKeyval } from "@vueuse/integrations/useIDBKeyval.mjs";
import { defineStore } from "pinia";

import UniMusicSync, { DocTicket, Entry, NamespaceId } from "@/plugins/UniMusicSync";
import { getPlatform } from "@/utils/os";
import { audioMimeTypeFromPath, traverseDirectory } from "@/utils/path";
import { Capacitor } from "@capacitor/core";
import { Directory, Filesystem } from "@capacitor/filesystem";
import { Ref, watch } from "vue";

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
	watchedNamespaces: Record<Path, DirectoryInfo>;
	namespaces: Record<NamespaceId, Path>;
}

export const useSync = defineStore("UniMusicSync", () => {
	const synchronizationData = useIDBKeyval<SyncData>("uniMusicSync", {
		watchedNamespaces: {},
		namespaces: {},
	});

	function log(...args: unknown[]): void {
		console.debug("%UniMusicSync:", "color: #9f00ff; font-weight: bold;", ...args);
	}

	async function data(): Promise<Ref<SyncData>> {
		if (synchronizationData.isFinished) {
			return synchronizationData.data;
		} else {
			await new Promise<void>((resolve) => {
				const unwatch = watch(synchronizationData.isFinished, (isFinished) => {
					if (isFinished) {
						unwatch();
						resolve();
					}
				});
			});
			return synchronizationData.data;
		}
	}

	async function createNamespace(path: string): Promise<NamespaceId> {
		const { namespace } = await UniMusicSync.createNamespace();
		synchronizationData.data.value.namespaces[namespace] = path;
		return namespace;
	}

	async function shareNamespace(namespace: NamespaceId): Promise<DocTicket> {
		const { ticket } = await UniMusicSync.share({ namespace });
		return ticket;
	}

	async function syncFiles(): Promise<void> {
		log(`- Reconnecting`);
		await UniMusicSync.reconnect();

		const syncData = synchronizationData.data.value;

		const recordedInfo: Record<Path, FileInfo> = {};

		for (const [namespace, directory] of Object.entries(syncData.namespaces)) {
			log(`- Sync namespace ${namespace} (${directory})`);

			await UniMusicSync.sync({ namespace });
			const syncedFiles = await UniMusicSync.getFiles({ namespace });

			log("synced files:", syncedFiles);

			let path: string;
			switch (getPlatform()) {
				case "android": {
					console.log(directory);
					// TODO: Manipulating SAF paths requires yet another Android API 🤦‍♂️
					throw new Error("todo");
				}
				case "electron": {
					const musicPath = await ElectronMusicPlayer!.getMusicPath();

					path = musicPath;
					if (directory.startsWith("./")) {
						path += directory.slice(2);
					} else if (directory.startsWith("/")) {
						path += directory.slice();
					} else {
						path += directory;
					}
					break;
				}
				case "ios":
					path = directory;
					break;
				case "web":
					return;
			}

			const watchedDirectory = syncData.watchedNamespaces[namespace];

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

			syncData.watchedNamespaces[namespace] = { lastRecordedInfo: recordedInfo };
		}
	}

	async function importNamespace(ticket: DocTicket, path: string): Promise<NamespaceId> {
		const syncData = synchronizationData.data.value;

		log(`Importing ticket ${ticket}`);
		const { namespace } = await UniMusicSync.import({ ticket });

		if (namespace in syncData.namespaces) {
			throw new Error(
				`Namespace ${namespace} was already imported, remove it first if you want to move it`,
			);
		}

		syncData.namespaces[namespace] = path;
		log(`Imported namespace ${namespace}`);
		return namespace;
	}

	return {
		data,
		syncFiles,
		importNamespace,
		createNamespace,
		shareNamespace,
	};
});
