import { registerPlugin } from "@capacitor/core";

export interface AudioLibrarySong {
	id: string;
	title?: string;
	artist?: string;
	genre?: string;
	path?: string;
	duration?: number;
	artwork?: string;
}

export interface AudioLibraryAlbum {
	id: string;
	title?: string;
	artist?: string;
	genre?: string;
	artwork?: unknown;
}

export interface AudioLibraryPlugin {
	getSongs(): Promise<{ songs: AudioLibrarySong[] }>;
	getAlbums(): Promise<{ albums: AudioLibraryAlbum[] }>;

	currentSongId(): Promise<{ id?: string }>;
	play(data: { id: string }): Promise<void>;
	pause(): void;
	resume(): void;

	getCurrentPlaybackTime(): Promise<{ currentPlaybackTime: number }>;
	/// time in seconds
	setCurrentPlaybackTime(data: { time: number }): void;
}

const AudioLibrary = registerPlugin<AudioLibraryPlugin>("AudioLibrary", {});

export default AudioLibrary;
