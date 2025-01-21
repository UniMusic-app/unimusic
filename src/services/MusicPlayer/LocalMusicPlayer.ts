import { LocalSong } from "@/types/music-player";

import { MusicPlayerService } from "../MusicPlayer";
import LocalMusicPlugin from "@/plugins/LocalMusicPlugin";
import { addMusicSessionActionHandlers } from "@/stores/music-player";
import { watch } from "vue";

// FIXME: On iOS after app has been relaunched files seem to change their paths or something else (?)
//		  So that local songs that are cached in queue from previous session aren't able to be played
//		  And have to be freshly re-added.
export class LocalMusicPlayer {
	static audio = new Audio();

	static updateCurrentTime(service: MusicPlayerService): void {
		service.time.value = this.audio.currentTime;
	}

	static async initialize(service: MusicPlayerService, song: LocalSong): Promise<void> {
		const { time, duration, volume } = service;

		time.value = 0;
		duration.value = song.data.duration ?? 1;

		const timeUpdateCallback = () => this.updateCurrentTime(service);
		this.audio.addEventListener("timeupdate", timeUpdateCallback);
		this.audio.addEventListener("playing", () => addMusicSessionActionHandlers(service), {
			once: true,
		});
		const unwatchVolume = watch(volume, (volume) => (this.audio.volume = volume), {
			immediate: true,
		});

		service.addEventListener(
			"initialize",
			async () => {
				await this.audio.pause();
				this.audio.remove();
				this.audio = new Audio();

				unwatchVolume();
			},
			{ once: true },
		);

		service.log("Initialized LocalMusicPlayer");
	}

	static async play(service: MusicPlayerService, song: LocalSong): Promise<void> {
		const { playing, loading } = service;
		const { audio } = this;

		if (this.audio.src) {
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
