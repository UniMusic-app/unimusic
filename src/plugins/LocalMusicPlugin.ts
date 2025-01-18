import { IAudioMetadata, parseBlob, parseBuffer } from "music-metadata";
import { Directory, Encoding, Filesystem } from "@capacitor/filesystem";

import { Capacitor } from "@capacitor/core";
import { LocalSong } from "@/types/music-player";

export interface LocalMusicSong {
	id: string;
	title?: string;
	artist?: string;
	genre?: string;
	path: string;
	duration?: number;
	artwork?: string;
	metadata: IAudioMetadata;
}

export class LocalMusicPluginWrapper {
	async getSongBlob(song: LocalSong): Promise<Blob> {
		console.log("!@# Reading");
		const { data } = await Filesystem.readFile({
			path: song.data.path,
		});
		console.log("!@# READ");

		if (data instanceof Blob) {
			return data;
		}

		// Data is in base64 string, so we convert it into a buffer
		const decodedData = atob(data);
		const buffer = new Uint8Array(decodedData.length).map((_, i) => {
			return decodedData.charCodeAt(i);
		});

		console.log("!@# RETURNINGGGGGGGG");

		return new Blob([buffer], {
			type: "audio/flac",
		});
	}

	async getSongs(): Promise<LocalMusicSong[]> {
		const songs: LocalMusicSong[] = [];

		await Filesystem.requestPermissions();

		// Required for Documents folder to show up in Files
		// NOTE: Hidden file doesn't work
		if (Capacitor.getPlatform() === "ios") {
			try {
				await Filesystem.stat({
					path: "/readme.txt",
					directory: Directory.Documents,
				});
			} catch {
				await Filesystem.writeFile({
					path: "/readme.txt",
					data:
						"Place your music files in this directory. They should be automatically recognized by the app.",
					encoding: Encoding.UTF8,
					directory: Directory.Documents,
				});
			}
		}

		const { files } = await Filesystem.readdir({
			path: "/",
			directory: Directory.Documents,
		});

		for (const file of files) {
			try {
				const { data } = await Filesystem.readFile({
					path: file.uri,
				});

				let metadata: IAudioMetadata;
				if (data instanceof Blob) {
					metadata = await parseBlob(data);
				} else {
					// Data is in base64 string, so we convert it into a buffer
					const decodedData = atob(data);
					const buffer = new Uint8Array(decodedData.length).map((_, i) => {
						return decodedData.charCodeAt(i);
					});
					metadata = await parseBuffer(buffer, {
						size: file.size,
						path: file.uri,
					});
				}

				const { common, format } = metadata;

				let base64Artwork: string | undefined;
				if (common.picture?.[0]?.data) {
					const base64Data = btoa(String.fromCharCode(...common.picture[0].data));
					base64Artwork = `data:text/plain;base64,${base64Data}`;
				}

				songs.push({
					id: file.name,
					artist: common.artist,
					title: common.title,
					duration: format.duration,
					genre: common.genre?.[0],
					artwork: base64Artwork,
					path: file.uri,
					metadata,
				});
			} catch (error) {
				console.log(
					"getSongs() errored on:",
					file.name,
					"with",
					error instanceof Error ? error.message : error,
				);
				continue;
			}
		}

		return songs;
	}
}

export default new LocalMusicPluginWrapper();
