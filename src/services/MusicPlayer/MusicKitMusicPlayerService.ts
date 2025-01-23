import { MusicKitSong } from "@/types/music-player";
import { useMusicKit } from "@/stores/musickit";
import { MusicPlayerService } from "@/services/MusicPlayer/MusicPlayerService";

export class MusicKitMusicPlayerService extends MusicPlayerService<MusicKitSong> {
	logName = "MusicKitMusicPlayerService";
	logColor = "#cc80dd";
	music!: MusicKit.MusicKitInstance;

	constructor() {
		super();
	}

	#timeUpdateCallback = () => {
		this.store.time = this.music!.currentPlaybackTime;
	};

	async handleInitialization(): Promise<void> {
		const music = await useMusicKit().music;

		music.repeatMode = MusicKit.PlayerRepeatMode.none;
		music.addEventListener("playbackTimeDidChange", this.#timeUpdateCallback);
		music.addEventListener("mediaCanPlay", () => this.store.addMusicSessionActionHandlers(), {
			once: true,
		});

		this.music = music;
	}

	async handleDeinitialization(): Promise<void> {
		this.music.removeEventListener("playbackTimeDidChange", this.#timeUpdateCallback);
	}

	async handlePlay(): Promise<void> {
		const { music } = this;

		await music.setQueue({ song: this.song!.id });
		await music.play();
	}

	async handleResume(): Promise<void> {
		await this.music.play();
	}

	async handlePause(): Promise<void> {
		await this.music.pause();
	}

	async handleStop(): Promise<void> {
		await this.music.stop();
	}

	async handleSeekToTime(timeInSeconds: number): Promise<void> {
		await this.music.seekToTime(timeInSeconds);
	}

	handleSetVolume(volume: number): void {
		this.music.volume = volume;
	}
}
