import { defineStore } from "pinia";
import { computed, readonly } from "vue";

import { MusicPlayerService } from "@/services/MusicPlayer";

export const useMusicPlayer = defineStore("MusicPlayer", () => {
	// Platform specific methods are put into the MusicPlayerService
	const musicPlayerService = new MusicPlayerService();

	const timeRemaining = computed(
		() => musicPlayerService.duration.value * (1 - musicPlayerService.progress.value),
	);

	return {
		loading: readonly(musicPlayerService.loading),
		playing: readonly(musicPlayerService.playing),
		play: musicPlayerService.play.bind(musicPlayerService),
		pause: musicPlayerService.pause.bind(musicPlayerService),
		togglePlay: musicPlayerService.togglePlay.bind(musicPlayerService),

		volume: musicPlayerService.volume,
		progress: musicPlayerService.progress,

		time: musicPlayerService.time,
		duration: musicPlayerService.duration,
		timeRemaining,

		queuedSongs: musicPlayerService.queuedSongs,
		queueIndex: musicPlayerService.queueIndex,
		add: musicPlayerService.add.bind(musicPlayerService),
		remove: musicPlayerService.remove.bind(musicPlayerService),
		hasPrevious: musicPlayerService.hasPrevious,
		hasNext: musicPlayerService.hasNext,
		skipPrevious: musicPlayerService.skipPrevious.bind(musicPlayerService),
		skipNext: musicPlayerService.skipNext.bind(musicPlayerService),
		currentSong: musicPlayerService.currentSong,
	};
});
