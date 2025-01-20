import { IAudioMetadata, parseBlob, parseBuffer } from "music-metadata";
import { Directory, Encoding, Filesystem } from "@capacitor/filesystem";

import { Capacitor } from "@capacitor/core";

import { registerPlugin } from "@capacitor/core";
import { base64StringToBuffer } from "@/utils/buffer";

interface LocalMusicPlugin {
	readSong(data: { path: string }): Promise<{ data: string }>;
	getSongs(): Promise<{
		songs: {
			id: string;
			title?: string;
			artist?: string;
			genre?: string;
			path: string;
			duration?: number;
		}[];
	}>;
}

const LocalMusic = registerPlugin<LocalMusicPlugin>("LocalMusic", {});

export interface LocalMusicSong {
	id: string;
	title?: string;
	artist?: string;
	genre?: string;
	path: string;
	duration?: number;
	artwork?: string;
}

export class LocalMusicPluginWrapper {
	async getSongBlob(song: LocalMusicSong): Promise<Blob> {
		let data: Blob | string;
		if (Capacitor.getPlatform() === "android") {
			({ data } = await LocalMusic.readSong({ path: song.path }));
		} else {
			({ data } = await Filesystem.readFile({ path: song.path }));
		}

		if (data instanceof Blob) {
			return data;
		}

		// Data is in base64 string, so we convert it into a buffer
		const buffer = base64StringToBuffer(data);
		return new Blob([buffer], {});
	}

	async parseLocalSong(data: Blob | string, path: string, size?: number): Promise<LocalMusicSong> {
		let metadata: IAudioMetadata;
		if (data instanceof Blob) {
			metadata = await parseBlob(data);
		} else {
			// Data is in base64 string, so we convert it into a buffer
			const buffer = base64StringToBuffer(data);
			metadata = await parseBuffer(buffer, { size, path });
		}

		const { common, format } = metadata;

		let base64Artwork: string | undefined;
		// TODO: Use canvas to resize the image to not store overly sized images
		// 		 Then store blobs in IndexedDB and lazily create a list of blob urls
		if (common.picture?.[0]?.data) {
			const buffer = common.picture[0].data;
			const base64Data = btoa(
				buffer.reduce<string>((data, byte) => data + String.fromCharCode(byte), ""),
			);
			base64Artwork = `data:text/plain;base64,${base64Data}`;
		}

		return {
			id: path,
			artist: common.artist,
			title: common.title,
			duration: format.duration,
			genre: common.genre?.[0],
			artwork: base64Artwork,
			path,
		};
	}

	async getSongs(): Promise<LocalMusicSong[]> {
		const songs: LocalMusicSong[] = [];

		if (Capacitor.getPlatform() === "android") {
			const { songs: localSongs } = await LocalMusic.getSongs();

			for (const localSong of localSongs) {
				const { data } = await LocalMusic.readSong({ path: localSong.path });
				const song = await this.parseLocalSong(data, localSong.path);
				songs.push(song);
			}

			return songs;
		}

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

				const song = await this.parseLocalSong(data, file.uri, file.size);

				songs.push(song);
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
