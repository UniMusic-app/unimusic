import { Song, SongPreview, SongType } from "@/services/Music/objects";
import { Service } from "@/services/Service";
import { Maybe } from "@/utils/types";
import { computed, ref } from "vue";

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

export interface LyricsServiceState {
	enabled: boolean;
	order: number;
}

export abstract class LyricsService extends Service<LyricsServiceState> {
	abstract name: string;
	abstract logName: string;
	abstract available: boolean;
	abstract description: string;

	#order = ref(0);
	order = computed({
		get: () => this.#order.value,
		set: async (value) => {
			await this.reorder(value);
		},
	});

	#enabled = ref(false);
	enabled = computed({
		get: () => {
			const enabled = this.#enabled.value;
			return this.available && enabled;
		},
		set: async (value) => {
			if (value) {
				await this.enable();
			} else {
				await this.disable();
			}
		},
	});

	constructor() {
		super();
		// Execute restoreState after the whole class has been instantiated
		queueMicrotask(() => void this.restoreState());
	}

	async reorder(value: number): Promise<void> {
		this.log("reorder", value);
		this.#order.value = value;
		await this.saveState({
			enabled: this.#enabled.value,
			order: value,
		});
	}

	async enable(): Promise<void> {
		this.log("enable");
		this.#enabled.value = true;
		await this.saveState({
			enabled: true,
			order: this.order.value,
		});
	}

	async disable(): Promise<void> {
		this.log("disable");
		this.#enabled.value = false;
		await this.saveState({
			enabled: false,
			order: this.order.value,
		});
	}

	async restoreState(): Promise<void> {
		if (!this.available) return;

		this.log("restoreState");
		const state = await this.getSavedState();
		if (!state) return;

		this.#order.value = state.order;
		this.#enabled.value = state.enabled;
	}

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

	handleGetLyricsFromISRC?(isrc: string): Maybe<Lyrics> | Promise<Maybe<Lyrics>>;
	async getLyricsFromISRC(isrc: string): Promise<Maybe<Lyrics>> {
		this.log("getLyricsFromISRC");

		if (!this.handleGetLyricsFromISRC) {
			throw new Error("This service does not support getLyricsFromISRC");
		}

		const lyrics = await this.handleGetLyricsFromISRC(isrc);
		return lyrics;
	}
}
