import { MusicKitSong } from "@/types/music-player";
import { MusicPlayerService } from "../MusicPlayer";
import { watch } from "vue";
import { useMusicKit } from "@/stores/musickit";

export class MusicKitMusicPlayer {
	static async updateCurrentTime(service: MusicPlayerService): Promise<void> {
		const { duration, time } = service;
		const music = await useMusicKit().music;

		time.value = music.currentPlaybackTime;
		if (time.value === duration.value) service.skipNext();
	}

	static async initialize(service: MusicPlayerService): Promise<void> {
		const { volume } = service;
		const music = await useMusicKit().music;

		const callback = () => MusicKitMusicPlayer.updateCurrentTime(service);
		music!.addEventListener("playbackTimeDidChange", callback);

		const unwatch = watch(volume, (volume) => (music!.volume = volume), { immediate: true });

		service.addEventListener("initialize", async () => {
			unwatch();
			music.removeEventListener("playbackTimeDidChange", callback);
		});

		service.log("Initialized MusicKitPlayer");
	}

	static async play(service: MusicPlayerService, song: MusicKitSong): Promise<void> {
		const { duration, time, loading, playing } = service;
		const music = await useMusicKit().music;

		if (music.queue.currentItem?.id === song.id) {
			await music.play();
			playing.value = true;
			return;
		}

		loading.value = true;

		music.addEventListener(
			"mediaCanPlay",
			() => {
				duration.value = music.currentPlaybackDuration;
				time.value = music.currentPlaybackTime;
				loading.value = false;
			},
			{ once: true },
		);

		music.repeatMode = MusicKit.PlayerRepeatMode.none;
		await music.setQueue({ song: song.id });
		await music.play();

		playing.value = true;
	}

	static async pause(service: MusicPlayerService): Promise<void> {
		const { playing } = service;
		const music = await useMusicKit().music;

		await music.pause();
		playing.value = false;
	}

	static async setCurrentPlaybackTime(timeInSeconds: number): Promise<void> {
		const music = await useMusicKit().music;
		music.seekToTime(timeInSeconds);
	}
}
