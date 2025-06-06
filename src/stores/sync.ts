import { useIDBKeyval } from "@vueuse/integrations/useIDBKeyval.mjs";
import { defineStore } from "pinia";

import StorageAccessFramework from "@/plugins/StorageAccessFramework";
import UniMusicSync, {
	DocTicket,
	NamespaceId,
	FileInfo as SyncFileInfo,
} from "@/plugins/UniMusicSync";
import { getPlatform, isElectron } from "@/utils/os";
import { audioMimeTypeFromPath } from "@/utils/path";
import { Directory, Filesystem } from "@capacitor/filesystem";
import { computed } from "vue";

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

	function log(...args: unknown[]): void {
		console.debug("%cUniMusicSync:", "color: #9f00ff; font-weight: bold;", ...args);
	}

	// TODO: Get or create namespace
	async function createNamespace(path: string): Promise<NamespaceId> {
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
		log(`- Reconnecting`);
		await UniMusicSync.reconnect();
		log(`- Reconnected`);

		const syncData = synchronizationData.value;

		const recordedInfo: Record<Path, FileInfo> = {};

		for (const [namespace, directory] of Object.entries(syncData.namespaces)) {
			log(`- Sync namespace ${namespace} (${directory})`);

			await UniMusicSync.sync({ namespace });
			const syncedFiles = await UniMusicSync.getFiles({ namespace });

			log("synced files:", syncedFiles);

			const watchedDirectory = syncData.watchedDirectories[namespace];

			const lastRecordedInfo = watchedDirectory?.lastRecordedInfo;
			console.log("DIRECTORY:", directory);
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
					// FIXME: Remove file if it exists on export
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

				if (lastInfo) {
					await UniMusicSync.deleteFile({ namespace, syncPath });
					log(`Deleting ${syncPath} (Local deletion)`);
					delete watchedDirectory!.lastRecordedInfo![syncPath];
					continue;
				}

				let destinationPath = `${directory}/${syncPath}`;
				log(`Retrieving ${syncPath} (Missing locally, saving to ${destinationPath})`);

				if (getPlatform() === "ios") {
					const { uri } = await Filesystem.getUri({
						path: destinationPath,
						directory: Directory.Documents,
					});
					destinationPath = decodeURIComponent(uri.replace("file://", ""));
				}

				await UniMusicSync.export({ namespace, syncPath, destinationPath });
			}

			syncData.watchedDirectories[namespace] = { lastRecordedInfo: recordedInfo };
		}
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
		data: synchronizationData,
		normalizeRelativePath,
		syncFiles,
		importNamespace,
		createNamespace,
		deleteNamespace,
		shareNamespace,
	};
});
