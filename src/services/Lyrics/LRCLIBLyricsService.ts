// This service implements Lyrics
// https://github.com/tranxuanthang/lrclib

import { Maybe } from "@/utils/types";
import { filledDisplayableArtist, Song, SongPreview, SongType } from "../Music/objects";
import { Lyrics, LyricsService, parseLyricsLines, parseSyncLyricsLines } from "./LyricsService";

const LRCLIB_ENDPOINT = "https://lrclib.net/api/";

interface LRCLIBGetResponse {
	id: number;
	trackName: string;
	artistName: string;
	albumName: string;
	duration: number;
	instrumental: boolean;
	plainLyrics: string;
	syncedLyrics?: string;
}

export class LRCLIBLyricsService extends LyricsService {
	logName = "LRCLIBLyricsService";
	logColor = "#000042";

	async handleGetLyricsFromSong<Type extends SongType>(
		song: Song<Type> | SongPreview<Type>,
	): Promise<Maybe<Lyrics>> {
		const url = new URL("get", LRCLIB_ENDPOINT);

		const { title, album, duration, artists } = song;

		if (title) url.searchParams.set("track_name", title);
		if (album && !album.includes("- Single")) url.searchParams.set("album_name", album);
		if (duration) url.searchParams.set("duration", String(duration));

		const displayableArtist = artists?.[0] && filledDisplayableArtist(artists[0]);
		if (displayableArtist && "title" in displayableArtist && displayableArtist?.title)
			url.searchParams.set("artist_name", displayableArtist.title);

		try {
			const response = await fetch(url);
			if (!response.ok) return;

			const json: LRCLIBGetResponse = await response.json();

			const lyrics: Lyrics = {
				provider: { title: "LRCLIB", url: "https://lrclib.net/" },
				lyrics: parseLyricsLines(json.plainLyrics),
			};

			if (json.syncedLyrics) {
				lyrics.syncedLyrics = parseSyncLyricsLines(json.syncedLyrics);
			}

			return lyrics;
		} catch (error) {
			this.log(`Failed fetching lyrics for ${song.title ?? song.id}`);
			console.error(error);
		}
	}
}
