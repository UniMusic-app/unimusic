import Innertube, { YTNodes } from "youtubei.js";

import type { SongImage, YouTubeSong } from "@/stores/music-player";
import { generateSongStyle } from "@/utils/songs";
import { MusicPlayerService } from "@/services/MusicPlayer/MusicPlayerService";

export async function youtubeSong(item: YTNodes.MusicResponsiveListItem): Promise<YouTubeSong> {
	if (!item.id) {
		throw new Error("Cannot generate YouTubeSong from item that doesn't have id");
	}

	let artwork: SongImage | undefined;
	let thumbnail = item.thumbnails?.at(-1);
	if (thumbnail) {
		// Get higher-res image
		const url = thumbnail.url.replace(`w${thumbnail.width}-h${thumbnail.height}`, "w256-h256");
		artwork = { url };
	}

	return {
		type: "youtube",

		id: item.id,
		title: item.title,
		album: item.album?.name,
		artist: item.artists?.[0]?.name,
		duration: item.duration?.seconds,
		// TODO: genre

		artwork,
		style: await generateSongStyle(artwork),

		data: {},
	};
}

export class YouTubeMusicService extends MusicPlayerService<YouTubeSong> {
	logName = "YouTubeMusicService";
	logColor = "#ff0000";

	#innertube!: Innertube;

	async handleInitialization(): Promise<void> {
		// youtube.js seems to be destructurizing fetch somewhere, which causes
		// "Illegal Invocation error", so we just provide our own
		// TODO: Proxy for web support
		const fetch = window.fetch.bind(window);
		this.#innertube = await Innertube.create({ fetch });
	}

	async handleDeinitialization(): Promise<void> {
		// TODO: Unimplemented
	}

	async handleSearchSongs(term: string, offset: number): Promise<YouTubeSong[]> {
		const results = await this.#innertube.music.search(term, {
			type: "song",
		});

		if (!results.contents) return [];

		const songs: YouTubeSong[] = [];

		for (const result of results.contents) {
			if (result.is(YTNodes.MusicShelf)) {
				for (const item of result.contents) {
					songs.push(await youtubeSong(item));
				}
			}
		}

		return songs;
	}

	async handleSearchHints(term: string): Promise<string[]> {
		const sections = await this.#innertube.music.getSearchSuggestions(term);
		const hints: string[] = [];
		for (const section of sections) {
			for (const suggestion of section.contents) {
				if (suggestion.is(YTNodes.SearchSuggestion)) {
					hints.push(suggestion.suggestion.toString());
				}
			}
		}
		return hints;
	}

	async handleLibrarySongs(offset: number): Promise<YouTubeSong[]> {
		// TODO: Unimplemented
		return [];
	}

	async handleRefreshLibrarySongs(): Promise<void> {
		// TODO: Unimplemented
	}

	handleRefreshSong(song: YouTubeSong): Promise<YouTubeSong> {
		throw new Error("Unimplemented.");
	}

	async handlePlay(): Promise<void> {
		// TODO: Unimplemented
	}

	async handleResume(): Promise<void> {
		// TODO: Unimplemented
	}

	async handlePause(): Promise<void> {
		// TODO: Unimplemented
	}

	async handleStop(): Promise<void> {
		// TODO: Unimplemented
	}

	handleSeekToTime(timeInSeconds: number): void | Promise<void> {
		// TODO: Unimplemented
	}

	handleSetVolume(timeInSeconds: number): void | Promise<void> {
		// TODO: Unimplemented
	}
}
