import { Service } from "./Service";
import type { AnySong } from "@/types/music-player";
import { computed, ref, watch } from "vue";
import { MusicKitMusicPlayer } from "./MusicPlayer/MusicKitMusicPlayer";
import { LibraryMusicPlayer } from "./MusicPlayer/LibraryMusicPlayer";
import { useStorage } from "@vueuse/core";

export class MusicPlayerService extends Service {
	logName = "MusicPlayerService";
	logColor = "#f8FF00";

	loading = ref(false);
	playing = ref(false);

	time = ref(0);
	duration = ref(1);
	progress = computed({
		get: () => this.time.value / this.duration.value,
		set: (progress) => {
			this.setCurrentPlaybackTime(progress * this.duration.value);
		},
	});

	queuedSongs = useStorage<AnySong[]>("queuedSongs", []);
	queueIndex = useStorage("queueIndex", 0);

	hasPrevious = computed(() => this.queueIndex.value > 0);
	hasNext = computed(() => this.queuedSongs.value.length > this.queueIndex.value + 1);
	currentSong = computed<AnySong | undefined>(() => this.queuedSongs.value[this.queueIndex.value]);

	// NOTE: volume control does not work on iOS due to Apple putting arbitrary restrictions around setting app volume
	volume = ref(1);

	constructor() {
		super();
		watch(this.currentSong, () => this.initialize(), { immediate: true });
	}

	async initialize(): Promise<void> {
		this.dispatchEvent(new Event("initialize"));
		const song = this.currentSong.value;
		switch (song?.type) {
			case "musickit":
				await MusicKitMusicPlayer.initialize(this);
				break;
			case "library":
				LibraryMusicPlayer.initialize(this, song);
				break;
		}
	}

	async play(): Promise<void> {
		const song = this.currentSong.value;
		switch (song?.type) {
			case "musickit":
				await MusicKitMusicPlayer.play(this, song);
				break;
			case "library":
				await LibraryMusicPlayer.play(this, song);
				break;
		}
	}

	async pause(): Promise<void> {
		const song = this.currentSong.value;
		switch (song?.type) {
			case "musickit":
				await MusicKitMusicPlayer.pause(this);
				break;
			case "library":
				await LibraryMusicPlayer.pause(this);
				break;
		}
	}

	async togglePlay(): Promise<void> {
		if (this.playing.value) {
			await this.pause();
		} else {
			await this.play();
		}
	}

	async setCurrentPlaybackTime(timeInSeconds: number): Promise<void> {
		const song = this.currentSong.value;
		switch (song?.type) {
			case "musickit":
				await MusicKitMusicPlayer.setCurrentPlaybackTime(timeInSeconds);
				break;
			case "library":
				await LibraryMusicPlayer.setCurrentPlaybackTime(timeInSeconds);
				break;
		}
	}

	add(song: AnySong, index = this.queuedSongs.value.length): void {
		this.queuedSongs.value.splice(index, 0, song);
	}

	remove(index: number): void {
		this.queuedSongs.value.splice(index, 1);
		if (index < this.queueIndex.value) {
			this.queueIndex.value = this.queueIndex.value - 1;
		}
	}

	async skipNext(): Promise<void> {
		if (!this.hasNext.value) return;
		this.queueIndex.value++;
		await this.play();
	}

	async skipPrevious(): Promise<void> {
		if (!this.hasPrevious.value) return;
		this.queueIndex.value--;
		await this.play();
	}
}
