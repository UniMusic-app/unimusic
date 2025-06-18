import { defineStore } from "pinia";
import { computed, reactive } from "vue";

import { MusicService, SearchFilter, SearchResultItem } from "@/services/Music/MusicService";

import { Lyrics } from "@/services/Lyrics/LyricsService";
import { Metadata, MetadataLookup } from "@/services/Metadata/MetadataService";
import {
	Album,
	AlbumPreview,
	Artist,
	ArtistPreview,
	Filled,
	Playlist,
	PlaylistId,
	PlaylistPreview,
	PlaylistType,
	Song,
	SongPreview,
	SongType,
} from "@/services/Music/objects";
import { abortableAsyncGenerator, racedIterators } from "@/utils/iterators";
import { Maybe } from "@/utils/types";
import { LocalImage } from "./local-images";
import { useLyricsServices } from "./lyrics-services";
import { useMetadataServices } from "./metadata-services";

export const useMusicServices = defineStore("MusicServices", () => {
	const lyricsServices = useLyricsServices();
	const metadataServices = useMetadataServices();

	const registeredServices = reactive<Record<string, MusicService>>({});
	const enabledServices = computed<MusicService[]>(() =>
		Object.values(registeredServices).filter((service) => service.enabled.value),
	);

	// #region Actions for managing services
	function registerService(service: MusicService): void {
		registeredServices[service.type] = service;
	}

	function getService(type?: string): Maybe<MusicService> {
		if (!type) {
			return;
		}

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

	async function retrievePlaylist(
		playlist: Playlist<SongType> | PlaylistPreview<SongType>,
	): Promise<Playlist> {
		if (playlist.kind === "playlistPreview") {
			return await getPlaylistFromPreview(playlist);
		}
		return playlist;
	}

	async function getPlaylistFromPreview(
		playlistPreview: PlaylistPreview<SongType>,
	): Promise<Playlist> {
		const service = getService(playlistPreview.type)!;
		const playlist = await service.getPlaylistFromPreview(playlistPreview);
		return playlist;
	}

	async function createPlaylist(
		type: SongType,
		title: string,
		artwork?: LocalImage,
	): Promise<Maybe<PlaylistId>> {
		return await getService(type)?.createPlaylist(title, artwork);
	}

	async function addSongsToPlaylist(
		playlist: Playlist<SongType> | PlaylistPreview<SongType>,
		songs: Song[],
	): Promise<void> {
		await getService(playlist.type)?.addSongsToPlaylist(playlist.id, songs);
	}

	async function getPlaylist(type: PlaylistType, id: string): Promise<Maybe<Playlist>> {
		return await getService(type)?.getPlaylist(id);
	}

	function libraryPlaylists(): AsyncGenerator<PlaylistPreview | Playlist> {
		const iterators: AsyncGenerator<PlaylistPreview | Playlist>[] = [];
		for (const service of enabledServices.value) {
			if (!service.handleGetLibraryPlaylists) continue;
			iterators.push(service.getLibraryPlaylists());
		}

		return abortableAsyncGenerator(racedIterators(iterators));
	}

	async function refreshLibraryPlaylists(): Promise<void> {
		await withAllServices((service) => {
			return service.handleRefreshLibraryPlaylists && service.refreshLibraryPlaylists();
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

	async function getSongFromPreview(songPreview: SongPreview): Promise<Song> {
		const service = getService(songPreview.type)!;
		const song = await service.getSongFromPreview(songPreview);
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

	async function getSong(type: SongType, id: string): Promise<Maybe<Song>> {
		return await getService(type)?.getSong(id);
	}

	async function retrieveAlbum(album: Album | AlbumPreview): Promise<Album> {
		if (album.kind === "albumPreview") {
			return await getAlbumFromPreview(album);
		}
		return album;
	}

	async function getAlbum(type: SongType, id: string): Promise<Maybe<Album>> {
		return await getService(type)?.getAlbum(id);
	}

	async function getAlbumFromPreview(albumPreview: AlbumPreview): Promise<Album> {
		const service = getService(albumPreview.type)!;
		const album = await service.getAlbumFromPreview(albumPreview);
		return album;
	}

	async function getSongsAlbum(song: Song): Promise<Maybe<Album>> {
		return await getService(song.type)?.getSongsAlbum(song);
	}

	async function getArtist(type: SongType, id: string): Promise<Maybe<Artist>> {
		return await getService(type)?.getArtist(id);
	}

	async function* getArtistsSongs(
		artist: Artist | Filled<Artist>,
	): AsyncGenerator<Song | SongPreview> {
		const service = getService(artist.type);
		if (!service?.handleGetArtistsSongs) return;

		yield* service.getArtistsSongs(artist);
	}

	function canGetLyrics(): boolean {
		return lyricsServices.enabledServices.length > 0;
	}
	async function getLyrics(song: Song): Promise<Maybe<Lyrics>> {
		return await lyricsServices.getLyricsFromSong(song);
	}

	function canGetMetadata(): boolean {
		return metadataServices.enabledServices.length > 0;
	}
	async function getMetadata(lookup: MetadataLookup): Promise<Maybe<Metadata>> {
		return await metadataServices.getMetadata(lookup);
	}
	// #endregion

	// #region Registering services
	if (__SERVICE_LOCAL__) {
		void import("@/services/Music/LocalMusicService").then((module) =>
			registerService(new module.LocalMusicService()),
		);
	}
	if (__SERVICE_MUSICKIT__) {
		void import("@/services/Music/MusicKitMusicService").then((module) =>
			registerService(new module.MusicKitMusicService()),
		);
	}
	if (__SERVICE_YOUTUBE__) {
		void import("@/services/Music/YouTubeMusicService").then((module) =>
			registerService(new module.YouTubeMusicService()),
		);
	}
	// #endregion

	return {
		registeredServices,
		enabledServices,

		registerService,
		getService,

		withAllServices,

		searchHints,
		searchForItems,

		canGetLyrics,
		getLyrics,

		canGetMetadata,
		getMetadata,

		getSong,
		refreshSong,
		retrieveSong,
		getSongFromPreview,
		getAvailableSongs,
		librarySongs,
		refreshLibrarySongs,

		getAlbum,
		retrieveAlbum,
		getAlbumFromPreview,
		libraryAlbums,
		refreshLibraryAlbums,
		getSongsAlbum,

		createPlaylist,
		addSongsToPlaylist,
		getPlaylist,
		retrievePlaylist,
		libraryPlaylists,
		refreshLibraryPlaylists,

		getArtist,
		getArtistsSongs,
		libraryArtists,
		refreshLibraryArtists,
	};
});
