import { defineStore } from "pinia";
import { computed, readonly, watch } from "vue";

import { MusicPlayerService } from "@/services/MusicPlayer";
import { Capacitor } from "@capacitor/core";

export function addMusicSessionActionHandlers(musicPlayerService: MusicPlayerService): void {
	if (!("mediaSession" in navigator)) return;

	navigator.mediaSession.setActionHandler("pause", async () => {
		await musicPlayerService.pause();
		navigator.mediaSession.playbackState = "paused";
	});
	navigator.mediaSession.setActionHandler("play", async () => {
		await musicPlayerService.play();
		navigator.mediaSession.playbackState = "playing";
	});
	navigator.mediaSession.setActionHandler("previoustrack", async () => {
		await musicPlayerService.skipPrevious();
	});
	navigator.mediaSession.setActionHandler("nexttrack", async () => {
		await musicPlayerService.skipNext();
	});
}

export const useMusicPlayer = defineStore("MusicPlayer", () => {
	// Platform specific methods are put into the MusicPlayerService
	const musicPlayerService = new MusicPlayerService();

	const timeRemaining = computed(
		() => musicPlayerService.duration.value * (1 - musicPlayerService.progress.value),
	);

	// Android's WebView doesn't support MediaSession
	if (Capacitor.getPlatform() === "android") {
		import("capacitor-music-controls-plugin").then(({ CapacitorMusicControls }) => {
			let musicControlsExist = false;
			watch(
				[musicPlayerService.hasPrevious, musicPlayerService.hasNext, musicPlayerService.currentSong],
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

			watch([musicPlayerService.playing, musicPlayerService.time], async ([isPlaying, elapsed]) => {
				if (!musicControlsExist) return;
				await CapacitorMusicControls.updateElapsed({ isPlaying, elapsed });
			});

			document.addEventListener("controlsNotification", async (event: Event) => {
				if (!("message" in event)) return;

				switch (event.message) {
					case "music-controls-play":
						await musicPlayerService.play();
						break;
					case "music-controls-pause":
						await musicPlayerService.pause();
						break;
					case "music-controls-next":
						await musicPlayerService.skipNext();
						break;
					case "music-controls-previous":
						await musicPlayerService.skipPrevious();
						break;
				}
			});
		});
	}

	// Web and IOS
	if (Capacitor.getPlatform() !== "android" && "mediaSession" in navigator) {
		// These action handlers MUST also be added after audio elements emitted "playing" event
		// Otherwise WKWebView on iOS does not respect the action handlers and shows the seek buttons
		addMusicSessionActionHandlers(musicPlayerService);

		watch([musicPlayerService.currentSong], ([song]) => {
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

	return {
		loading: readonly(musicPlayerService.loading),
		playing: readonly(musicPlayerService.playing),
		play: musicPlayerService.play.bind(musicPlayerService),
		pause: musicPlayerService.pause.bind(musicPlayerService),
		togglePlay: musicPlayerService.togglePlay.bind(musicPlayerService),
		initialize: musicPlayerService.initialize.bind(musicPlayerService),

		volume: musicPlayerService.volume,
		progress: musicPlayerService.progress,

		time: musicPlayerService.time,
		duration: musicPlayerService.duration,
		timeRemaining,

		queuedSongs: computed(() => musicPlayerService.queuedSongs.data.value),
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
