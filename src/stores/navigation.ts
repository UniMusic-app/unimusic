import { useIonRouter } from "@ionic/vue";
import { defineStore } from "pinia";

import {
	Album,
	AlbumPreview,
	Artist,
	ArtistPreview,
	filledDisplayableArtist,
	Song,
	SongPreview,
} from "@/services/Music/objects";

export const useNavigation = defineStore("Navigation", () => {
	const ionRouter = useIonRouter();

	function goToSong(song: Song | SongPreview): void {
		if (!song.id) {
			// TODO: Error toast when song has no id
			return;
		}

		ionRouter.push(`/items/songs/${song.type}/${song.id}`);
	}

	function goToAlbum(album: Album | AlbumPreview): void {
		ionRouter.push(`/items/albums/album/${album.type}/${album.id}`);
	}

	function goToSongsAlbum(song: Song | SongPreview): void {
		if (!song.id) {
			// TODO: Error toast when song has no id
			return;
		}

		ionRouter.push(`/items/albums/song/${song.type}/${song.id}`);
	}

	function goToArtist(artist: Artist | ArtistPreview): void {
		ionRouter.push(`/items/artists/${artist.type}/${artist.id}`);
	}

	function goToSongsArtist(song: Song | SongPreview): void {
		const artist = song.artists.map(filledDisplayableArtist).find((artist) => "id" in artist);
		if (!artist?.id) {
			// TODO: Error toast when song has no artist with id
			return;
		}

		ionRouter.push(`/items/artists/${artist.type}/${artist.id}`);
	}

	return {
		goToSong,
		goToAlbum,
		goToSongsAlbum,
		goToArtist,
		goToSongsArtist,
	};
});
