import { defineStore } from "pinia";
import { computed, readonly, ref, watch } from "vue";
import { useStorage } from "@vueuse/core";

import { AnySong } from "@/types/music-player";
import { useMusicKit } from "./musickit";

export const useMusicPlayer = defineStore("MusicPlayer", () => {
	const musicKit = useMusicKit();

	const playing = ref(false);
	const currentTime = ref(0);
	const duration = ref(1);
	const progress = computed({
		get: () => currentTime.value / duration.value,
		set(progress) {
			musicKit.music!.seekToTime(progress * duration.value);
		},
	});
	const timeRemaining = computed(() => duration.value * (1 - progress.value));
	const loading = ref(false);
	// FIXME: volume control does not work on ios
	const volume = ref(1);
	watch(volume, (volume) => {
		musicKit.music!.volume = volume;
	});

	const queuedSongs = useStorage<AnySong[]>("queuedSongs", []);
	const queueIndex = useStorage("queueIndex", 0);

	const hasPrevious = computed(() => queueIndex.value > 0);
	const hasNext = computed(() => queuedSongs.value.length > queueIndex.value + 1);

	musicKit.withMusic(async (music) => {
		music.repeatMode = MusicKit.PlayerRepeatMode.none;

		music.addEventListener("mediaCanPlay", () => {
			duration.value = music.currentPlaybackDuration;
			currentTime.value = music.currentPlaybackTime;
			loading.value = false;
		});

		music.addEventListener("playbackTimeDidChange", () => {
			currentTime.value = music.currentPlaybackTime;

			if (currentTime.value === duration.value) skipNext();
		});
	});

	async function play(): Promise<void> {
		const song = currentSong.value;
		if (!song) {
			console.warn("Tried to play a song thats undefined");
			return;
		}

		switch (song.type) {
			case "musickit": {
				const music = musicKit.music!;
				if (music.nowPlayingItem?.id !== song.id) {
					loading.value = true;
					await music.setQueue({ song: song.id });
				}
				await music.play();
				playing.value = true;
				break;
			}
			default:
				throw new Error("unimplemented");
		}
	}

	async function pause(): Promise<void> {
		const song = currentSong.value;
		if (!song) {
			console.warn("Tried to play a song thats undefined");
			return;
		}

		console.info("Trying to pause", song);

		switch (song.type) {
			case "musickit": {
				const music = musicKit.music!;
				await music.pause();
				playing.value = false;
				break;
			}
			default:
				throw new Error("unimplemented");
		}
	}

	function togglePlay(): void {
		if (playing.value) pause();
		else play();
	}

	function add(song: AnySong, index = queuedSongs.value.length): void {
		queuedSongs.value.splice(index, 0, song);
	}

	async function skipNext(): Promise<void> {
		if (!hasNext.value) return;
		queueIndex.value++;
		await play();
	}

	async function skipPrevious(): Promise<void> {
		if (!hasPrevious.value) return;
		queueIndex.value--;
		await play();
	}

	const currentSong = computed<AnySong | undefined>(() => queuedSongs.value[queueIndex.value]);

	return {
		loading,

		playing: readonly(playing),
		play,
		pause,
		togglePlay,

		volume,
		progress,
		currentTime,
		duration,
		timeRemaining,

		queuedSongs,
		queueIndex,
		add,
		hasPrevious,
		hasNext,
		skipPrevious,
		skipNext,
		currentSong,
	};
});
