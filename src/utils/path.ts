import LocalMusic from "@/plugins/LocalMusic";
import { Capacitor } from "@capacitor/core";
import { Directory, Filesystem } from "@capacitor/filesystem";
import { relative } from "path";
import { getPlatform } from "./os";

export function audioMimeTypeFromPath(path: string): string | undefined {
	const extension = path.slice(path.lastIndexOf(".") + 1);

	switch (extension) {
		case "aac":
			return "audio/aac";
		case "mid":
		case "midi":
			return "audio/midi";
		case "mp3":
			return "audio/mp3";
		case "mpeg":
		case "mpg":
			return "audio/mpeg";
		case "m4a":
			return "audio/m4a";
		case "aiff":
		case "aif":
		case "aifc":
			return "audio/aiff";
		case "oga":
		case "ogg":
		case "opus":
			return "audio/ogg";
		case "wav":
			return "audio/wav";
		case "weba":
		case "webm":
			return "audio/webm";
		case "flac":
			return "audio/flac";
		case "3gp":
			return "audio/3gpp";
		default:
			return;
	}
}

export async function* getSongPaths(): AsyncGenerator<{ filePath: string; id?: string }> {
	switch (getPlatform()) {
		case "android": {
			const { songs } = await LocalMusic.getSongs();
			for (const song of songs) {
				yield { id: song.id, filePath: song.path };
			}
			break;
		}
		case "electron": {
			const musicPath = await ElectronMusicPlayer!.getMusicPath();
			yield* traverseDirectory(musicPath);
			break;
		}
		case "ios":
			yield* traverseDirectory("/");
			break;
	}
}

export function pathBreadcrumbs(path: string): string[] {
	switch (getPlatform()) {
		case "ios": {
			path = decodeURIComponent(path);
			const importantFolders = ["Application", "Documents", "Library"];
			const pathSegments = path.split(/\/+/).filter(Boolean);
			const i = pathSegments.findLastIndex((segment) => importantFolders.includes(segment));
			if (i === -1) {
				return pathSegments;
			} else {
				return pathSegments.slice(i);
			}
		}
		case "android": {
			// Example SAF URI: content://com.android.externalstorage.documents/tree/primary%3AMusic%2FMu
			const knownProviders: Record<string, string> = {
				"com.android.externalstorage.documents": "Documents",
				"com.android.providers.downloads.documents": "Downloads",
			};

			if (!path.startsWith("content://") || !path.includes("/tree/")) {
				throw new Error(`Unsupported path type: ${path}. Please report this issue.`);
			}
			path = decodeURIComponent(path);
			path = path.replace("content://", "");

			const [providerId, treePath] = path.split("/tree/") as [string, string];
			const [volume, relativePath] = treePath.split(":") as [string, string];

			let provider = providerId;
			if (knownProviders[providerId]) {
				provider = knownProviders[provider]!;
			}

			return [provider, volume, ...relativePath.split(/\/+/)];
		}
		default:
			return path.split(/[/\\]+/);
	}
}

export async function* traverseDirectory(path: string): AsyncGenerator<{ filePath: string }> {
	if (getPlatform() === "electron") {
		for (const filePath of await ElectronMusicPlayer!.traverseDirectory(path)) {
			yield { filePath };
		}
	} else {
		const { Directory, Filesystem } = await import("@capacitor/filesystem");

		const { files } = await Filesystem.readdir({
			path,
			directory: Directory.Documents,
		});

		for (const file of files) {
			// Ignore deleted files
			if (file.name === ".Trash") {
				continue;
			}

			const filePath = `${path}/${file.name}`;

			if (file.type === "directory") {
				yield* traverseDirectory(filePath);
				continue;
			}

			yield { filePath };
		}
	}
}

export async function getFileStream(path: string): Promise<ReadableStream<Uint8Array>> {
	switch (getPlatform()) {
		case "electron": {
			const buffer = await ElectronMusicPlayer!.readFile(path);
			const stream = new ReadableStream({
				start(controller): void {
					controller.enqueue(buffer);
					controller.close();
				},
			});
			return stream;
		}
		case "android": {
			const fileSrc = Capacitor.convertFileSrc(path);
			const response = await fetch(fileSrc);
			if (!response.body) {
				throw new Error(`Failed retrieving file stream for ${path}: body is empty.`);
			}
			return response.body;
		}
		default: {
			const { uri } = await Filesystem.getUri({
				path: path,
				directory: Directory.Documents,
			});
			const fileSrc = Capacitor.convertFileSrc(uri);
			const response = await fetch(fileSrc);
			if (!response.body) {
				throw new Error(`Failed retrieving file stream for ${path}: body is empty.`);
			}
			return response.body;
		}
	}
}
