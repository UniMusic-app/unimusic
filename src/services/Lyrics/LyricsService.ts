import { Song, SongPreview, SongType } from "@/services/Music/objects";
import { Service } from "@/services/Service";
import { Maybe } from "@/utils/types";

interface SyncedLine {
	/** Timestamp in seconds */
	timestamp: number;
	line: string;
}

export interface Lyrics {
	provider: { title: string; url?: string };
	lyrics: string[];
	syncedLyrics?: SyncedLine[];
}

function normalizeLyricsLine(line: string): string {
	return line.trim();
}

export function parseLyricsLines(lines: string): string[] {
	return lines.split(/\r?\n/).map(normalizeLyricsLine);
}

/** Lines must be in '[mm:ss.xx] lyric' or '[mm:ss.xxx] lyric' format */
export function parseSyncLyricsLines(lines: string): SyncedLine[] {
	return lines.split(/\r?\n/).map((rawLine) => {
		const [_, time, line] = rawLine.match(/\[(.+?)\](.+)/)! as [string, string, string];
		const [minutes, seconds, millis] = time!.split(/:|\./, 3) as [string, string, string];

		// prettier-ignore
		const timestamp =
			Number(minutes) * 60
			+ Number(seconds)
			+ Number(millis) / (millis.length === 2 ? 100 : 1000);

		return { timestamp, line: normalizeLyricsLine(line) };
	});
}

export abstract class LyricsService extends Service {
	handleGetLyricsFromSong?<Type extends SongType>(
		song: Song<Type> | SongPreview<Type>,
	): Maybe<Lyrics> | Promise<Maybe<Lyrics>>;
	async getLyricsFromSong<Type extends SongType>(
		song: Song<Type> | SongPreview<Type>,
	): Promise<Maybe<Lyrics>> {
		this.log("getLyricsFromSong");

		if (!this.handleGetLyricsFromSong) {
			throw new Error("This service does not support getLyricsFromSong");
		}

		const lyrics = await this.handleGetLyricsFromSong(song);
		return lyrics;
	}

	handleGetLyricsFromISRC?(): Maybe<Lyrics> | Promise<Maybe<Lyrics>>;
	async getLyricsFromISRC(): Promise<Maybe<Lyrics>> {
		this.log("getLyricsFromISRC");

		if (!this.handleGetLyricsFromISRC) {
			throw new Error("This service does not support getLyricsFromISRC");
		}

		const lyrics = await this.handleGetLyricsFromISRC();
		return lyrics;
	}
}
