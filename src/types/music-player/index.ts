import { LocalMusicSong } from "@/plugins/LocalMusicPlugin";

export interface Song<Type extends string, Data> {
	type: Type;

	id: string;
	title?: string;
	artist?: string;
	artworkUrl?: string;

	data: Data;
}

export type MusicKitSong = Song<"musickit", MusicKit.Songs>;
export type LocalSong = Song<"local", LocalMusicSong>;

export type AnySong = MusicKitSong | LocalSong;
