import { defineStore, storeToRefs } from "pinia";
import { computed, shallowRef, watch } from "vue";

import { useLocalImages } from "@/stores/local-images";
import { useMusicServices } from "@/stores/music-services";
import { useMusicPlayerState } from "@/stores/music-state";

import { MusicService } from "@/services/Music/MusicService";

import MediaSession, { MediaSessionPluginEvent } from "@/plugins/MediaSession";
import { Album, AlbumPreview, filledAlbum, Song, SongPreview } from "@/services/Music/objects";
import { getPlatform } from "@/utils/os";
import { formatArtists } from "@/utils/songs";
import { watchAsync } from "@/utils/vue";

export const useMusicPlayer = defineStore("MusicPlayer", () => {
	const localImages = useLocalImages();

	const state = useMusicPlayerState();
	const { currentQueueSong, currentSong, autoplay, playing, time, volume } = storeToRefs(state);

	const services = useMusicServices();
	const { enabledServices } = storeToRefs(services);

	// #region Managing services
	const currentService = shallowRef<MusicService>();
	watch([currentSong, enabledServices], ([song]) => {
		currentService.value = services.getService(song?.type);
	});

	watch(volume, async (volume) => {
		await services.withAllServices((service) => service.setVolume(volume));
	});

	// Automatically change songs
	let abortController = new AbortController();
	watch([currentQueueSong, enabledServices], async () => {
		abortController.abort();
		abortController = new AbortController();

		await state.loadingCounters.queueChange.onLoaded();

		state.loading.queueChange = true;

		try {
			const service = currentService.value;
			if (service) {
				await service.changeSong(currentSong.value!);

				abortController.signal.throwIfAborted();

				switch (autoplay.value) {
					case true:
						await play();
						break;
					case "auto":
						autoplay.value = true;
						break;
					case false:
						break;
				}
			} else {
				await services.withAllServices((service) => service.stop());
			}
		} catch {}

		state.loading.queueChange = false;
	});
	// #endregion

	// #region Actions for managing MusicPlayer
	const hasPrevious = computed(() => state.queueIndex > 0);
	const hasNext = computed(() => state.queue.length > state.queueIndex + 1);

	async function seekToTime(time: number): Promise<void> {
		await currentService?.value?.seekToTime(time);
	}

	async function setQueueIndex(index: number): Promise<void> {
		if (index < 0 || index >= state.queue.length) {
			throw new Error(`Tried to set queue index outside of queue bounds (index = ${index})`);
		}
		state.queueIndex = index;
		await state.loadingCounters.queueChange.onLoaded();
	}
	async function skipPrevious(): Promise<void> {
		if (!hasPrevious.value) return;
		state.queueIndex -= 1;
		await state.loadingCounters.queueChange.onLoaded();
	}
	async function skipNext(): Promise<void> {
		if (!hasNext.value) return;
		state.queueIndex += 1;
		await state.loadingCounters.queueChange.onLoaded();
	}

	async function play(): Promise<void> {
		await currentService.value?.play();
	}
	async function pause(): Promise<void> {
		await currentService.value?.pause();
	}

	async function togglePlay(): Promise<void> {
		await currentService.value?.togglePlay();
	}

	// TODO: Handle failed retrieve song (show toast or something)
	async function playSongNow(song: Song | SongPreview): Promise<void> {
		if (state.currentSong?.type === song.type && state.currentSong.id === song.id) {
			await play();
			return;
		}
		await state.addToQueue(await services.retrieveSong(song), state.queueIndex);
	}

	async function playSongNext(song: Song | SongPreview): Promise<void> {
		await state.addToQueue(await services.retrieveSong(song), state.queueIndex + 1);
	}

	async function playSongLast(song: Song | SongPreview): Promise<void> {
		await state.addToQueue(await services.retrieveSong(song));
	}

	async function getAlbumSongs(album: Album | AlbumPreview): Promise<Song[]> {
		const retrieved = await services.retrieveAlbum(album);
		const filled = filledAlbum(retrieved);
		return await services.getAvailableSongs(filled.songs.map(({ song }) => song));
	}

	async function playAlbumNow(album: Album | AlbumPreview): Promise<void> {
		const songs = await getAlbumSongs(album);
		state.setQueue(songs);
		state.queueIndex = 0;
	}

	async function playAlbumNext(album: Album | AlbumPreview): Promise<void> {
		const songs = await getAlbumSongs(album);
		await state.insertIntoQueue(songs, state.queueIndex + 1);
	}

	async function playAlbumLast(album: Album | AlbumPreview): Promise<void> {
		const songs = await getAlbumSongs(album);
		await state.insertIntoQueue(songs);
	}

	// #endregion

	// #region System Music Controls

	addMusicSessionActionHandlers();

	let initializedMediaSession = false;
	watchAsync(
		currentSong,
		async (song) => {
			if (!initializedMediaSession) {
				await MediaSession.initialize();

				document.addEventListener("mediaSession", async (e) => {
					const event = e as MediaSessionPluginEvent;

					switch (event.action) {
						case "play":
							await play();
							break;
						case "pause":
							await pause();
							break;

						case "seekTo":
							await seekToTime(event.position);
							break;

						case "skipToPrevious":
							await skipPrevious();
							break;
						case "skipToNext":
							await skipNext();
							break;
					}
				});

				initializedMediaSession = true;
			}

			// Since iOS's WKWebView is actually its own separate app setting AVAudioSession inside this app does nothing.
			// However I was lucky enough to find this W3C AudioSession draft: https://w3c.github.io/audio-session.
			// And Apple does indeed support it in both Safari and WKWebView. According to https://caniwebview.com/search/?s=audiosession it is supported since iOS 16.4
			// NOTE: This might change in the future, since its not a web standard
			if ("audioSession" in navigator) {
				(navigator.audioSession as { type: string }).type = "playback";
			}

			if (song) {
				let artwork: string | undefined;
				if (song.artwork) {
					if (getPlatform() === "android") {
						artwork = await localImages.getUri(song.artwork, "large");
					} else {
						artwork = await localImages.getUrl(song.artwork, "large");
					}
				}

				await MediaSession.setMetadata({
					title: song.title,
					artist: formatArtists(song.artists),
					album: song.album,
					artwork: artwork,
					duration: song.duration,
				});

				await MediaSession.setPlaybackState({
					state: state.playing ? "playing" : "paused",
					elapsed: time.value,
				});
			} else {
				await MediaSession.setPlaybackState({ state: "none", elapsed: 0 });
			}
		},
		{ immediate: true },
	);

	watchAsync(playing, async (playing) => {
		if (!initializedMediaSession) return;

		await MediaSession.setPlaybackState({
			state: playing ? "playing" : "paused",
			elapsed: time.value,
		});
	});

	/**
	 * These action handlers MUST also be added after audio elements emitted "playing" event
	 * Otherwise WKWebView on iOS does not respect the action handlers and shows the seek buttons
	 */
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
	// #endregion

	// #region Properties
	const progress = computed({
		get: () => state.time / state.duration,
		set: async (progress) => {
			const time = progress * state.duration;
			await seekToTime(time);
		},
	});

	const timeRemaining = computed(() => state.duration - state.time);
	// #endregion

	return {
		play,
		pause,
		togglePlay,
		hasPrevious,
		skipPrevious,
		hasNext,
		skipNext,
		setQueueIndex,
		seekToTime,

		playSongNow,
		playSongNext,
		playSongLast,

		getAlbumSongs,
		playAlbumNow,
		playAlbumNext,
		playAlbumLast,

		progress,
		timeRemaining,

		addMusicSessionActionHandlers,

		state,
		services,
	};
});
