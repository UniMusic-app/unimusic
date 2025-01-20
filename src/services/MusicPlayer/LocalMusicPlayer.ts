import { LocalSong } from "@/types/music-player";

import { MusicPlayerService } from "../MusicPlayer";
import LocalMusicPlugin from "@/plugins/LocalMusicPlugin";

// FIXME: After app has been relaunched files seem to change their paths or something else (?)
//		  So that local songs that are cached in queue from previous session aren't able to be played
//		  And have to be freshly re-added.
export class LocalMusicPlayer {
	static audio = document.createElement("audio");

	static updateCurrentTime(service: MusicPlayerService): void {
		service.time.value = this.audio.currentTime;
	}

	static async initialize(service: MusicPlayerService, song: LocalSong): Promise<void> {
		const { time, duration } = service;

		time.value = 0;
		duration.value = song.data.duration ?? 1;

		// TODO: Use capacitor-music-controls-plugin
		if ("mediaSession" in navigator) {
			navigator.mediaSession.metadata = new window.MediaMetadata({
				title: song.title,
				artist: song.artist,
				artwork: song.artworkUrl ? [{ src: song.artworkUrl }] : undefined,
			});
		}

		const callback = () => this.updateCurrentTime(service);
		this.audio.addEventListener("timeupdate", callback);

		service.addEventListener(
			"initialize",
			() => this.audio.removeEventListener("timeupdate", callback),
			{ once: true },
		);

		service.log("Initialized LocalMusicPlayer");
	}

	static #currentSongId: string;
	static async play(service: MusicPlayerService, song: LocalSong): Promise<void> {
		const { playing, loading } = service;
		const { audio } = this;

		if (this.#currentSongId === song.id) {
			await audio.play();
			playing.value = true;
			return;
		}

		loading.value = true;

		const blob = await LocalMusicPlugin.getSongBlob(song.data);
		const url = URL.createObjectURL(blob);
		service.addEventListener("initialize", () => URL.revokeObjectURL(url), { once: true });

		audio.src = url;
		await audio.play();
		loading.value = false;
		playing.value = true;

		this.#currentSongId = song.id;
	}

	static async pause(service: MusicPlayerService): Promise<void> {
		const { playing } = service;
		await this.audio.pause();
		playing.value = false;
	}

	static async setCurrentPlaybackTime(timeInSeconds: number): Promise<void> {
		this.audio.currentTime = timeInSeconds;
	}
}
