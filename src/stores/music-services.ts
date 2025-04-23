import { defineStore } from "pinia";
import { computed, reactive } from "vue";

import { MusicService } from "@/services/Music/MusicService";

import { LocalMusicService } from "@/services/Music/LocalMusicService";
import { MusicKitMusicService } from "@/services/Music/MusicKitMusicService";
import { YouTubeMusicService } from "@/services/Music/YouTubeMusicService";

import {
	Album,
	AlbumPreview,
	Artist,
	ArtistPreview,
	Filled,
	Song,
	SongPreview,
} from "@/services/Music/objects";
import { raceIterators } from "@/utils/iterators";
import { Maybe } from "@/utils/types";

export const useMusicServices = defineStore("MusicServices", () => {
	const registeredServices = reactive<Record<string, MusicService>>({});
	const enabledServices = computed<MusicService[]>(() =>
		Object.values(registeredServices).filter((service) => service.enabled.value),
	);

	// #region Actions for managing services
	function registerService(service: MusicService): void {
		registeredServices[service.type] = service;
	}

	function getService(type: string): Maybe<MusicService> {
		const service = registeredServices[type];
		if (service?.enabled?.value) {
			return service;
		}
	}
	// #endregion

	// #region Actions for calling service methods
	function withAllServices<T>(callback: (service: MusicService) => T): Promise<Awaited<T>[]> {
		return Promise.all(enabledServices.value.map(callback));
	}

	async function* searchHints(term: string): AsyncGenerator<string> {
		const iterators: AsyncGenerator<string>[] = [];
		for (const service of enabledServices.value) {
			if (!service.handleGetSearchHints) continue;
			iterators.push(service.getSearchHints(term));
		}

		// Do not yield duplicates
		const hints = new Set();
		for await (const hint of raceIterators(iterators)) {
			if (!hints.has(hint)) {
				yield hint;
				hints.add(hint);
			}
		}
	}

	async function* searchSongs(
		term: string,
		offset = 0,
		options?: { signal: AbortSignal },
	): AsyncGenerator<SongPreview | Song> {
		const iterators: AsyncGenerator<SongPreview | Song>[] = [];
		for (const service of enabledServices.value) {
			if (!service.handleSearchSongs) continue;
			iterators.push(service.searchSongs(term, offset, options));
		}

		for await (const searchResult of raceIterators(iterators)) {
			yield searchResult;
		}
	}

	async function* librarySongs(offset = 0): AsyncGenerator<Song> {
		const iterators: AsyncGenerator<Song>[] = [];
		for (const service of enabledServices.value) {
			if (!service.handleGetLibrarySongs) continue;
			iterators.push(service.getLibrarySongs(offset));
		}

		for await (const song of raceIterators(iterators)) {
			yield song;
		}
	}

	async function refreshLibrarySongs(): Promise<void> {
		await withAllServices((service) => {
			return service.handleRefreshLibrarySongs && service.refreshLibrarySongs();
		});
	}

	async function* libraryAlbums(): AsyncGenerator<AlbumPreview | Album> {
		const iterators: AsyncGenerator<AlbumPreview | Album>[] = [];
		for (const service of enabledServices.value) {
			if (!service.handleGetLibraryAlbums) continue;
			iterators.push(service.getLibraryAlbums());
		}

		for await (const album of raceIterators(iterators)) {
			yield album;
		}
	}

	async function refreshLibraryAlbums(): Promise<void> {
		await withAllServices((service) => {
			return service.handleRefreshLibraryAlbums && service.refreshLibraryAlbums();
		});
	}

	async function* libraryArtists(): AsyncGenerator<ArtistPreview | Artist> {
		const iterators: AsyncGenerator<ArtistPreview | Artist>[] = [];
		for (const service of enabledServices.value) {
			if (!service.handleGetLibraryArtists) continue;
			iterators.push(service.getLibraryArtists());
		}

		for await (const artist of raceIterators(iterators)) {
			yield artist;
		}
	}

	async function refreshLibraryArtists(): Promise<void> {
		await withAllServices((service) => {
			return service.handleRefreshLibraryArtists && service.refreshLibraryArtists();
		});
	}

	async function refreshSong(song: Song): Promise<Maybe<Song>> {
		return await getService(song.type)?.refreshSong(song);
	}

	async function getSongFromPreview(searchResult: SongPreview): Promise<Song> {
		const service = getService(searchResult.type)!;
		const song = await service.getSongFromPreview(searchResult);
		return song;
	}

	async function retrieveSong(song: Song | SongPreview): Promise<Song> {
		if (song.kind === "songPreview") {
			return await getSongFromPreview(song);
		}
		return song;
	}

	async function getAvailableSongs(songs: (Song | SongPreview)[]): Promise<Song[]> {
		return await Promise.all(songs.filter((song) => song?.available).map(retrieveSong));
	}

	async function getSong(type: Song["type"], id: string): Promise<Maybe<Song>> {
		return await getService(type)?.getSong(id);
	}

	async function getAlbum(type: Song["type"], id: string): Promise<Maybe<Album>> {
		return await getService(type)?.getAlbum(id);
	}

	async function getSongsAlbum(song: Song): Promise<Maybe<Album>> {
		return await getService(song.type)?.getSongsAlbum(song);
	}

	async function getArtist(type: Song["type"], id: string): Promise<Maybe<Artist>> {
		return await getService(type)?.getArtist(id);
	}

	async function* getArtistsSongs(
		artist: Artist | Filled<Artist>,
		offset: number,
	): AsyncGenerator<Song | SongPreview> {
		const service = getService(artist.type);
		if (!service?.handleGetArtistsSongs) return;

		yield* service.getArtistsSongs(artist, offset);
	}
	// #endregion

	registerService(new MusicKitMusicService());
	registerService(new YouTubeMusicService());
	registerService(new LocalMusicService());

	return {
		registeredServices,
		enabledServices,

		registerService,
		getService,

		withAllServices,

		searchHints,
		searchSongs,

		getSong,
		refreshSong,
		retrieveSong,
		getSongFromPreview,
		getAvailableSongs,
		librarySongs,
		refreshLibrarySongs,

		getAlbum,
		libraryAlbums,
		refreshLibraryAlbums,
		getSongsAlbum,

		getArtist,
		getArtistsSongs,
		libraryArtists,
		refreshLibraryArtists,
	};
});
