import { AudioLibrarySong } from "@/plugins/AudioLibrary";

export interface Song<Type extends string, Data> {
	type: Type;

	id: string;
	title?: string;
	artist?: string;
	artworkUrl?: string;

	data: Data;
}

export type MusicKitSong = Song<"musickit", MusicKit.Songs>;
export type LibrarySong = Song<"library", AudioLibrarySong>;

export type AnySong = MusicKitSong | LibrarySong;
