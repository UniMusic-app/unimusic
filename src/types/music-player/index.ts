import { LocalMusicSong } from "@/plugins/LocalMusicPlugin";

export interface Song<Type extends string, Data> {
	type: Type;

	id: string;
	title?: string;
	artist?: string;
	album?: string;
	artworkUrl?: string;
	duration?: number;

	data: Data;
}

export type MusicKitSong = Song<"musickit", MusicKit.Songs>;
export type LocalSong = Song<"local", LocalMusicSong>;

export type AnySong = MusicKitSong | LocalSong;
