import { LocalImage } from "@/stores/local-images";
import { getCachedFromKey } from "./cache";
import { Filled, Identifiable } from "./shared";
import type { SongKey, SongPreviewKey, SongType } from "./song";

type PlaylistTypes = Record<SongType, undefined> & {
	unimusic?: {
		importInfo?: {
			service: SongType;
			playlistId: string;
		};
		convert?: {
			from: SongType;
			to: SongType;
		};
	};
};

export type PlaylistType = SongType | "unimusic";
export type PlaylistId = string;

export interface Playlist<Type extends PlaylistType = PlaylistType> extends Identifiable {
	type: Type;
	id: PlaylistId;
	kind: "playlist";

	title: string;
	artwork?: LocalImage;

	songs: PlaylistSong<Type>[];
	data?: PlaylistTypes[Type];
}

export type PlaylistSong<Type extends PlaylistType> = Type extends SongType
	? SongKey<Type> | SongPreviewKey<Type>
	: SongKey | SongPreviewKey;

export interface PlaylistPreview<Type extends PlaylistType = PlaylistType> extends Identifiable {
	type: Type;
	id: PlaylistId;
	kind: "playlistPreview";

	title: string;
	artwork?: LocalImage;
}

export function filledPlaylistPreview(playlistPreview: PlaylistPreview): Filled<PlaylistPreview> {
	return {
		type: playlistPreview.type,
		id: playlistPreview.id,
		kind: "playlistPreview",

		title: playlistPreview.title,
		artwork: playlistPreview.artwork,
	};
}

export function filledPlaylist(playlist: Playlist): Filled<Playlist> {
	return {
		type: playlist.type,
		id: playlist.id,
		kind: "playlist",

		title: playlist.title,
		artwork: playlist.artwork,

		songs: playlist.songs.map((song) => {
			const cached = getCachedFromKey(song);
			if (!cached) {
				throw new Error(`Playlist tried to retrieve song ${song}, but it is not cached`);
			}
			return cached;
		}),
	};
}
