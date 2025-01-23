import { defineStore } from "pinia";
import { computed, ref, watch } from "vue";
import { useStorage, watchDebounced } from "@vueuse/core";
import { useIDBKeyval } from "@vueuse/integrations/useIDBKeyval";

import { Capacitor } from "@capacitor/core";
import { AnySong } from "@/types/music-player";

import { LocalMusicPlayerService } from "@/services/MusicPlayer/LocalMusicPlayerService";
import { MusicKitMusicPlayerService } from "@/services/MusicPlayer/MusicKitMusicPlayerService";
import { MusicPlayerService } from "@/services/MusicPlayer/MusicPlayerService";

export const useMusicPlayer = defineStore("MusicPlayer", () => {
	const services = {
		local: new LocalMusicPlayerService(),
		musickit: new MusicKitMusicPlayerService(),
	};

	const queuedSongs = useIDBKeyval<AnySong[]>("queuedSongs", []);
	const queueIndex = useStorage("queueIndex", 0);
	const currentSong = computed<AnySong | undefined>(() => queuedSongs.data.value[queueIndex.value]);

	const currentService = computed<MusicPlayerService | undefined>(() => {
		const song = currentSong.value;
		return song && services[song.type];
	});

	let autoPlay = false;
	watchDebounced(
		currentSong,
		async (song) => {
			if (song) {
				const service = currentService.value!;
				await service.changeSong(song!);
				if (autoPlay) {
					await service.play();
				} else {
					await service.initialize();
					autoPlay = true;
				}
			} else {
				await MusicPlayerService.stopServices();
			}
		},
		{ debounce: 500 },
	);

	const loading = ref(false);
	const playing = ref(false);
	const volume = ref(1);

	const time = ref(0);
	const duration = ref(1);
	const progress = computed({
		get: () => time.value / duration.value,
		set: (progress) => {
			currentService.value?.seekToTime(progress * duration.value);
		},
	});

	const hasPrevious = computed(() => queueIndex.value > 0);
	const hasNext = computed(() => queuedSongs.data.value.length > queueIndex.value + 1);

	const timeRemaining = computed(() => duration.value * (1 - progress.value));

	function add(song: AnySong, index = queuedSongs.data.value.length): void {
		queuedSongs.data.value.splice(index, 0, song);
	}

	function remove(index: number): void {
		queuedSongs.data.value.splice(index, 1);
		if (index < queueIndex.value) {
			queueIndex.value = queueIndex.value - 1;
		}
	}

	function play() {
		return currentService.value?.play();
	}

	function pause() {
		return currentService.value?.pause();
	}

	function togglePlay() {
		return currentService.value?.togglePlay();
	}

	async function skipPrevious() {
		if (!hasPrevious.value) return;
		queueIndex.value--;
	}

	async function skipNext() {
		if (!hasNext.value) return;
		queueIndex.value++;
	}

	// Android's WebView doesn't support MediaSession
	if (Capacitor.getPlatform() === "android") {
		import("capacitor-music-controls-plugin").then(({ CapacitorMusicControls }) => {
			let musicControlsExist = false;
			watch(
				[hasPrevious, hasNext, currentSong],
				async ([hasPrev, hasNext, currentSong]) => {
					if (musicControlsExist) {
						musicControlsExist = false;
						await CapacitorMusicControls.destroy();
					}

					await CapacitorMusicControls.create({
						isPlaying: false,
						hasPrev,
						hasSkipBackward: false,
						hasNext,
						hasSkipForward: false,

						track: currentSong?.title ?? "",
						artist: currentSong?.artist ?? "",
						album: currentSong?.album ?? "",

						// FIXME: Local artworks
						cover: currentSong?.artworkUrl ?? "",

						hasClose: false,
						dismissable: false,

						hasScrubbing: true,
						elapsed: 0,
						duration: currentSong?.duration ?? 0,

						playIcon: "media_play",
						pauseIcon: "media_pause",
						prevIcon: "media_prev",
						nextIcon: "media_next",
						closeIcon: "media_close",
						notificationIcon: "notification",
					});
					musicControlsExist = true;
				},
				{ immediate: true },
			);

			watch([playing, time], async ([isPlaying, elapsed]) => {
				if (!musicControlsExist) return;
				await CapacitorMusicControls.updateElapsed({ isPlaying, elapsed });
			});

			document.addEventListener("controlsNotification", async (event: Event) => {
				if (!("message" in event)) return;

				switch (event.message) {
					case "music-controls-play":
						await play();
						break;
					case "music-controls-pause":
						await pause();
						break;
					case "music-controls-next":
						await skipNext();
						break;
					case "music-controls-previous":
						await skipPrevious();
						break;
				}
			});
		});
	}

	// Web and IOS
	if (Capacitor.getPlatform() !== "android" && "mediaSession" in navigator) {
		// These action handlers MUST also be added after audio elements emitted "playing" event
		// Otherwise WKWebView on iOS does not respect the action handlers and shows the seek buttons
		addMusicSessionActionHandlers();

		watch([currentSong], ([song]) => {
			if (!song) {
				navigator.mediaSession.metadata = null;
				navigator.mediaSession.playbackState = "none";
				return;
			}

			navigator.mediaSession.metadata = new window.MediaMetadata({
				title: song.title,
				artist: song.artist,
				album: song.album,
				artwork: song.artworkUrl ? [{ src: song.artworkUrl }] : undefined,
			});
		});
	}

	function addMusicSessionActionHandlers(): void {
		if (!("mediaSession" in navigator)) return;

		navigator.mediaSession.setActionHandler("pause", async () => {
			await pause();
			navigator.mediaSession.playbackState = "paused";
		});
		navigator.mediaSession.setActionHandler("play", async () => {
			await play();
			navigator.mediaSession.playbackState = "playing";
		});
		navigator.mediaSession.setActionHandler("previoustrack", async () => {
			await skipPrevious();
		});
		navigator.mediaSession.setActionHandler("nexttrack", async () => {
			await skipNext();
		});
	}

	return {
		loading,
		playing,
		play,
		pause,
		togglePlay,

		volume,
		progress,

		time,
		duration,
		timeRemaining,

		queuedSongs: computed(() => queuedSongs.data.value),
		queueIndex,
		add,
		remove,
		hasPrevious,
		hasNext,
		skipPrevious,
		skipNext,
		currentSong,

		addMusicSessionActionHandlers,
	};
});
