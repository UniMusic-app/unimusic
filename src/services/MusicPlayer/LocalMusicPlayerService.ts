import { MusicPlayerService } from "@/services/MusicPlayer/MusicPlayerService";
import LocalMusicPlugin, { LocalMusicSong } from "@/plugins/LocalMusicPlugin";
import { LocalSong } from "@/stores/music-player";
import Fuse from "fuse.js";
import { localSong } from "@/utils/songs";

export class LocalMusicPlayerService extends MusicPlayerService<LocalSong> {
	logName = "LocalMusicPlayerService";
	logColor = "#ddd480";
	audio?: HTMLAudioElement;

	constructor() {
		super();
	}

	async handleSearchHints(term: string): Promise<string[]> {
		return [];
	}

	#fuse?: Fuse<LocalMusicSong>;
	async handleSearchSongs(term: string, offset: number): Promise<LocalSong[]> {
		// TODO: Maybe split results in smaller chunks and actually paginate it?
		if (offset > 0) {
			return [];
		}

		if (!this.#fuse) {
			const allSongs = await LocalMusicPlugin.getSongs();

			// TODO: This might require some messing around with distance/threshold settings to not make it excessively loose
			this.#fuse = new Fuse(allSongs, {
				keys: ["title", "artist", "album", "genre"] satisfies (keyof LocalMusicSong)[],
			});
		}

		const results = this.#fuse.search(term);
		const songs: LocalSong[] = [];

		for (const result of results) {
			songs.push(localSong(result.item));
		}

		return songs;
	}

	async handleInitialization(): Promise<void> {
		const audio = new Audio();
		audio.addEventListener("timeupdate", () => {
			this.store.time = audio.currentTime;
		});
		audio.addEventListener("playing", () => {
			this.store.addMusicSessionActionHandlers();
		});
		this.audio = audio;
	}

	async handleDeinitialization(): Promise<void> {
		URL.revokeObjectURL(this.audio!.src);
		this.audio!.remove();
		this.audio = undefined;
	}

	async handlePlay(): Promise<void> {
		const blob = await LocalMusicPlugin.getSongBlob(this.song!.data.path);
		const url = URL.createObjectURL(blob);
		this.audio!.src = url;
		this.audio!.play();
	}

	async handleResume(): Promise<void> {
		await this.audio!.play();
	}

	async handlePause(): Promise<void> {
		await this.audio!.pause();
	}

	async handleStop(): Promise<void> {
		await this.audio!.pause();
	}

	handleSeekToTime(timeInSeconds: number): void {
		this.audio!.currentTime = timeInSeconds;
	}

	handleSetVolume(volume: number): void {
		this.audio!.volume = volume;
	}
}
