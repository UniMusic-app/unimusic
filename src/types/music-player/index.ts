export interface Song<Type extends string, Data> {
	type: Type;

	id: string;
	name: string;
	artist: string;
	artworkUrl: string;

	data?: Data;
}

export type MusicKitSong = Song<"musickit", MusicKit.Songs>;
export type AnySong = MusicKitSong;
