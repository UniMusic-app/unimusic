export interface Song<Type extends string, Data = never> {
	type: Type;

	id: string;
	title?: string;
	artist?: string;
	album?: string;
	artworkUrl?: string;
	duration?: number;

	data: Data;
}

export type MusicKitSong = Song<"musickit", { bgColor?: string }>;
export type LocalSong = Song<"local", { path: string }>;

export type AnySong = MusicKitSong | LocalSong;
