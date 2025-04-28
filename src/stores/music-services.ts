import { defineStore } from "pinia";
import { computed, reactive } from "vue";

import { MusicService, SearchFilter, SearchResultItem } from "@/services/Music/MusicService";

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
import { abortableAsyncGenerator, racedIterators } from "@/utils/iterators";
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
		for await (const hint of racedIterators(iterators)) {
			if (!hints.has(hint)) {
				yield hint;
				hints.add(hint);
			}
		}
	}

	function searchForItems(term: string, filter: SearchFilter): AsyncGenerator<SearchResultItem> {
		const iterators: AsyncGenerator<SearchResultItem>[] = [];
		for (const service of enabledServices.value) {
			if (!service.handleSearchForItems) continue;
			iterators.push(service.searchForItems(term, filter));
		}

		return abortableAsyncGenerator(racedIterators(iterators));
	}

	function librarySongs(): AsyncGenerator<Song> {
		const iterators: AsyncGenerator<Song>[] = [];
		for (const service of enabledServices.value) {
			if (!service.handleGetLibrarySongs) continue;
			iterators.push(service.getLibrarySongs());
		}

		return abortableAsyncGenerator(racedIterators(iterators));
	}

	async function refreshLibrarySongs(): Promise<void> {
		await withAllServices((service) => {
			return service.handleRefreshLibrarySongs && service.refreshLibrarySongs();
		});
	}

	function libraryAlbums(): AsyncGenerator<AlbumPreview | Album> {
		const iterators: AsyncGenerator<AlbumPreview | Album>[] = [];
		for (const service of enabledServices.value) {
			if (!service.handleGetLibraryAlbums) continue;
			iterators.push(service.getLibraryAlbums());
		}

		return abortableAsyncGenerator(racedIterators(iterators));
	}

	async function refreshLibraryAlbums(): Promise<void> {
		await withAllServices((service) => {
			return service.handleRefreshLibraryAlbums && service.refreshLibraryAlbums();
		});
	}

	function libraryArtists(): AsyncGenerator<ArtistPreview | Artist> {
		const iterators: AsyncGenerator<ArtistPreview | Artist>[] = [];
		for (const service of enabledServices.value) {
			if (!service.handleGetLibraryArtists) continue;
			iterators.push(service.getLibraryArtists());
		}

		return abortableAsyncGenerator(racedIterators(iterators));
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
	): AsyncGenerator<Song | SongPreview> {
		const service = getService(artist.type);
		if (!service?.handleGetArtistsSongs) return;

		yield* service.getArtistsSongs(artist);
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
		searchForItems,

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
