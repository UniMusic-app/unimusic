import { LocalSong } from "@/types/music-player";
import { MusicPlayerService } from "@/services/MusicPlayer/MusicPlayerService";
import LocalMusicPlugin from "@/plugins/LocalMusicPlugin";

export class LocalMusicPlayerService extends MusicPlayerService<LocalSong> {
	logName = "LocalMusicPlayerService";
	logColor = "#ddd480";
	audio?: HTMLAudioElement;

	constructor() {
		super();
	}

	async handleInitialization(): Promise<void> {
		const audio = new Audio();
		audio.addEventListener("timeupdate", () => {
			this.store.time = audio.currentTime;
		});
		audio.addEventListener("playing", () => {
			this.store.addMusicSessionActionHandlers();
		});
		this.audio = audio;
	}

	async handleDeinitialization(): Promise<void> {
		URL.revokeObjectURL(this.audio!.src);
		this.audio!.remove();
		this.audio = undefined;
	}

	async handlePlay(): Promise<void> {
		const blob = await LocalMusicPlugin.getSongBlob(this.song!.data.path);
		const url = URL.createObjectURL(blob);
		this.audio!.src = url;
		this.audio!.play();
	}

	async handleResume(): Promise<void> {
		await this.audio!.play();
	}

	async handlePause(): Promise<void> {
		await this.audio!.pause();
	}

	async handleStop(): Promise<void> {
		await this.audio!.pause();
	}

	handleSeekToTime(timeInSeconds: number): void {
		this.audio!.currentTime = timeInSeconds;
	}

	handleSetVolume(volume: number): void {
		this.audio!.volume = volume;
	}
}
