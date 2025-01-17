import { LibrarySong } from "@/types/music-player";
import { MusicPlayerService } from "../MusicPlayer";
import AudioLibrary from "@/plugins/AudioLibrary";

export class LibraryMusicPlayer {
	// TODO: events for updating current time
	static updateCurrentTime(_service: MusicPlayerService): void {}

	static initialize(service: MusicPlayerService, song: LibrarySong): void {
		service.log("Initialized LibraryMusicPlayer");
		const { time, duration } = service;

		time.value = 0;
		duration.value = song.data.duration ?? 1;
	}

	static async play(service: MusicPlayerService, song: LibrarySong): Promise<void> {
		const { playing, loading } = service;

		if ((await AudioLibrary.currentSongId()).id === song.id) {
			await AudioLibrary.resume();
			playing.value = true;
			return;
		}

		loading.value = true;
		await AudioLibrary.play({ id: song.id });
		loading.value = false;
		playing.value = true;
	}

	static async pause(service: MusicPlayerService): Promise<void> {
		const { playing } = service;
		await AudioLibrary.pause();
		playing.value = false;
	}

	static async setCurrentPlaybackTime(timeInSeconds: number): Promise<void> {
		await AudioLibrary.setCurrentPlaybackTime({ time: timeInSeconds });
	}
}
