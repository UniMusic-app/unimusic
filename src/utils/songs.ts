import { LocalMusicSong } from "@/plugins/LocalMusicPlugin";
import { AnySong, LocalSong, MusicKitSong } from "@/stores/music-player";

export function musicKitSong(song: MusicKit.Songs): MusicKitSong {
	return {
		type: "musickit",

		id: song.id,
		title: song.attributes?.name,
		artist: song.attributes?.artistName,
		album: song.attributes?.albumName,
		artworkUrl:
			song.attributes?.artwork && MusicKit.formatArtworkURL(song.attributes?.artwork, 256, 256),
		duration: song.attributes?.durationInMillis && song.attributes?.durationInMillis / 1000,

		data: {
			bgColor: song.attributes?.artwork.bgColor,
		},
	};
}

export function localSong(song: LocalMusicSong): LocalSong {
	return {
		type: "local",

		id: song.id,
		title: song.title,
		artist: song.artist,
		album: song.album,
		artworkUrl: song.artwork,
		duration: song.duration,

		data: {
			path: song.path,
		},
	};
}

export function songTypeDisplayName(song: AnySong): string {
	switch (song.type) {
		case "local":
			return "Local";
		case "musickit":
			return "Apple Music";
	}
}
