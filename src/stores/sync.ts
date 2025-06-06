import { useIDBKeyval } from "@vueuse/integrations/useIDBKeyval.mjs";
import { defineStore } from "pinia";

import StorageAccessFramework from "@/plugins/StorageAccessFramework";
import UniMusicSync, {
	DocTicket,
	NamespaceId,
	FileInfo as SyncFileInfo,
} from "@/plugins/UniMusicSync";
import { getPlatform } from "@/utils/os";
import { audioMimeTypeFromPath } from "@/utils/path";
import { Directory, Filesystem } from "@capacitor/filesystem";
import { computed, ref } from "vue";

type Path = string;

interface FileInfo {
	sourcePath: Path;
	mtime: number;
	size: number;
	entry?: SyncFileInfo;
}

interface DirectoryInfo {
	lastRecordedInfo?: Record<Path, FileInfo>;
}

export interface SyncData {
	watchedDirectories: Record<NamespaceId, DirectoryInfo>;
	namespaces: Record<NamespaceId, Path>;
}

export const useSync = defineStore("UniMusicSync", () => {
	const $synchronizationData = useIDBKeyval<SyncData>("uniMusicSync", {
		watchedDirectories: {},
		namespaces: {},
	});
	const synchronizationData = computed(() => $synchronizationData.data.value);

	const status = ref<"idle" | "syncing">("idle");

	function log(...args: unknown[]): void {
		console.debug("%cUniMusicSync:", "color: #9f00ff; font-weight: bold;", ...args);
	}

	async function getOrCreateNamespace(path: string): Promise<NamespaceId> {
		for (const [namespace, namespacePath] of Object.entries(synchronizationData.value.namespaces)) {
			if (path === namespacePath) return namespace;
		}

		const { namespace } = await UniMusicSync.createNamespace();
		synchronizationData.value.namespaces[namespace] = path;
		return namespace;
	}

	async function shareNamespace(namespace: NamespaceId): Promise<DocTicket> {
		const { ticket } = await UniMusicSync.share({ namespace });
		return ticket;
	}

	async function deleteNamespace(namespace: NamespaceId): Promise<void> {
		delete synchronizationData.value.namespaces[namespace];
		delete synchronizationData.value.watchedDirectories[namespace];
		await UniMusicSync.deleteNamespace({ namespace });
	}

	function normalizeRelativePath(path: string): string {
		path = decodeURIComponent(path);
		// Convert windows-style path to be unix-like
		path = path.replaceAll("\\", "/");
		// Remove leading slashes
		path = path.replace(/^\/+/, "");
		// Remove leading slashes
		path = path.replace(/\/+$/, "");

		const segments = path.split(/\/+/);
		segments.filter((segment) => {
			switch (segment) {
				case "":
				case ".":
					return false;
				case "..":
					throw new Error("Paths going up a directory are not allowed");
			}
		});

		const result = segments.join("/");
		if (!result.length) {
			throw new Error(`Invalid path '${path}' results in being empty after normalization`);
		}

		return result;
	}

	async function* traverseRelativeDirectory(
		rootPath: string,
		path = "",
	): AsyncGenerator<{ relativePath: string; absolutePath: string }> {
		switch (getPlatform()) {
			case "electron": {
				for (const absolutePath of await ElectronBridge!.fileSystem.traverseDirectory(rootPath)) {
					const relativePath = normalizeRelativePath(absolutePath.replace(rootPath, ""));
					yield { absolutePath, relativePath };
				}
				break;
			}
			case "ios": {
				const { files } = await Filesystem.readdir({
					path: `${rootPath}/${path}`,
					directory: Directory.Documents,
				});

				for (const file of files) {
					// Ignore hidden files
					if (file.name.startsWith(".")) {
						continue;
					}

					const filePath = normalizeRelativePath(`${path}/${file.name}`);

					if (file.type === "directory") {
						yield* traverseRelativeDirectory(rootPath, filePath);
						continue;
					}

					yield { relativePath: filePath, absolutePath: `${rootPath}/${filePath}` };
				}
				break;
			}
			case "android": {
				const { files } = await StorageAccessFramework.readdir({
					treeUri: rootPath,
					path: path!,
				});

				for (const file of files) {
					// Ignore hidden files
					if (file.name.startsWith(".")) {
						continue;
					}

					const filePath = normalizeRelativePath(`${path}/${file.name}`);

					if (file.type === "directory") {
						yield* traverseRelativeDirectory(rootPath, filePath);
						continue;
					}

					yield { relativePath: filePath, absolutePath: `${rootPath}/${filePath}` };
				}
				break;
			}
		}
	}

	async function getFileInfo(
		absolutePath: string,
		relativePath: string,
		directory: string,
	): Promise<FileInfo> {
		switch (getPlatform()) {
			case "electron": {
				const { mtime, size } = await ElectronBridge!.fileSystem.statFile(absolutePath);

				return {
					sourcePath: absolutePath,
					mtime,
					size,
				};
			}
			case "android": {
				const { uri, mtime, size } = await StorageAccessFramework.stat({
					treeUri: directory,
					path: relativePath,
				});

				return {
					sourcePath: uri,
					mtime,
					size,
				};
			}
			case "ios": {
				const { uri, mtime, size } = await Filesystem.stat({
					path: absolutePath,
					directory: Directory.Documents,
				});

				return {
					sourcePath: uri,
					mtime,
					size,
				};
			}
			default:
				throw new Error("Unsupported");
		}
	}

	async function syncFiles(): Promise<void> {
		if (status.value === "syncing") {
			return;
		}

		status.value = "syncing";

		log(`- Reconnecting`);
		await UniMusicSync.reconnect();
		log(`- Reconnected`);

		const syncData = synchronizationData.value;

		const recordedInfo: Record<Path, FileInfo> = {};

		for (const [namespace, directory] of Object.entries(syncData.namespaces)) {
			log(`- Sync namespace ${namespace} (${directory})`);

			try {
				await UniMusicSync.sync({ namespace });
			} catch (error) {
				console.warn(error);
				log(`- Sync failed, skipping namespace ${namespace}`);
			}

			const syncedFiles = await UniMusicSync.getFiles({ namespace });

			log("Files to sync:", syncedFiles);

			const watchedDirectory = syncData.watchedDirectories[namespace];

			const lastRecordedInfo = watchedDirectory?.lastRecordedInfo;
			for await (const { relativePath, absolutePath } of traverseRelativeDirectory(directory)) {
				const syncPath = relativePath;

				if (!audioMimeTypeFromPath(syncPath)) continue;
				log(`- Sync file ${syncPath}`);

				const lastFileInfo = lastRecordedInfo?.[syncPath];

				const { sourcePath, mtime, size } = await getFileInfo(absolutePath, syncPath, directory);
				const entry = syncedFiles[syncPath];

				if (!entry || !lastFileInfo) {
					log(`Updating ${syncPath} (New local entry)`);
					await UniMusicSync.writeFile({ namespace, syncPath, sourcePath });
				} else if (lastFileInfo?.entry && entry.contentHash !== lastFileInfo.entry.contentHash) {
					log(`Updating ${syncPath} (New remote value | EXPORT)`);
					await UniMusicSync.exportHash({ fileHash: entry.contentHash, destinationPath: sourcePath });
				} else if (lastFileInfo.mtime !== mtime || lastFileInfo.size !== size) {
					log(`Updating ${syncPath} (File got modified)`);
					await UniMusicSync.writeFile({ namespace, syncPath, sourcePath });
				} else {
					log(`File ${syncPath} already up to date`);
				}

				recordedInfo[syncPath] = { sourcePath, mtime, size, entry };
			}

			const seenFiles = new Set(Object.keys(recordedInfo));
			const allFiles = new Set(Object.keys(syncedFiles));

			for (const syncPath of allFiles.difference(seenFiles)) {
				const lastInfo = watchedDirectory?.lastRecordedInfo?.[syncPath];

				console.log(watchedDirectory, lastInfo);

				if (lastInfo) {
					log(`Deleting ${syncPath} (Local deletion)`);
					await UniMusicSync.deleteFile({ namespace, syncPath });
					delete watchedDirectory!.lastRecordedInfo![syncPath];
					continue;
				}

				let destinationPath = `${directory}/${syncPath}`;

				switch (getPlatform()) {
					case "ios": {
						const { uri } = await Filesystem.getUri({
							path: destinationPath,
							directory: Directory.Documents,
						});
						destinationPath = decodeURIComponent(uri.replace("file://", ""));
						break;
					}
					case "android": {
						const { uri } = await StorageAccessFramework.ensureFile({
							treeUri: directory,
							path: syncPath,
						});
						destinationPath = uri;
						break;
					}
				}
				log(`Retrieving ${syncPath} (Missing locally, saving to ${destinationPath})`);
				await UniMusicSync.export({ namespace, syncPath, destinationPath });
			}

			syncData.watchedDirectories[namespace] = { lastRecordedInfo: recordedInfo };
		}

		log("Sync Finished");
		status.value = "idle";
	}

	async function importNamespace(ticket: DocTicket, path: string): Promise<NamespaceId> {
		const syncData = synchronizationData.value;

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
		status,
		data: synchronizationData,
		normalizeRelativePath,
		syncFiles,
		importNamespace,
		getOrCreateNamespace,
		deleteNamespace,
		shareNamespace,
	};
});
