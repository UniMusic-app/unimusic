import { toRaw } from "vue";

import Fuse from "fuse.js";
import { parseWebStream, selectCover } from "music-metadata";

import { LocalImage, useLocalImages } from "@/stores/local-images";

import {
	MusicService,
	MusicServiceEvent,
	SearchFilter,
	SearchResultItem,
} from "@/services/Music/MusicService";

const metadataService = new MusicBrainzLyricsService();

import { generateHash, generateUUID } from "@/utils/crypto";
import { getPlatform } from "@/utils/os";
import { audioMimeTypeFromPath, getFileStream, getSongPaths } from "@/utils/path";
import { Maybe } from "@/utils/types";
import { Directory, Encoding, Filesystem } from "@capacitor/filesystem";
import { MusicBrainzLyricsService } from "../Metadata/MusicBrainzMetadataService";
import {
	Album,
	AlbumSong,
	Artist,
	ArtistKey,
	ArtistPreview,
	cache,
	DisplayableArtist,
	Filled,
	filledDisplayableArtist,
	generateCacheMethod,
	getAllCached,
	getCachedFromKey,
	getKey,
	removeFromCache,
	Song,
	SongPreview,
} from "./objects";

const getCached = generateCacheMethod("local");

type LocalAlbum = Album<"local">;
type LocalAlbumSong = AlbumSong<"local">;
type LocalArtist = Artist<"local">;
type LocalArtistPreview = ArtistPreview<"local">;
type _LocalArtistKey = ArtistKey<"local">;
type LocalSong = Song<"local">;
type LocalSongPreview = SongPreview<"local">;
type LocalDisplayableArtist = DisplayableArtist<"local">;

async function parseLocalSong(path: string, id: string): Promise<LocalSong> {
	const stream = await getFileStream(path);
	const metadata = await parseWebStream(
		stream,
		{ path, mimeType: audioMimeTypeFromPath(path) },
		{ duration: true, skipPostHeaders: true },
	);

	const { common, format } = metadata;

	const artists: LocalDisplayableArtist[] = [];
	if (common.artists?.length) {
		for (let i = 0; i < common.artists.length; ++i) {
			const title = common.artists[i]!;
			// TODO: Is there a better way to identify artists?
			const id = title;

			const artistPreview = cache<LocalArtistPreview>({
				id,
				type: "local",
				kind: "artistPreview",
				title,
			});
			artists.push(getKey(artistPreview));
		}
	}

	const fileName = path.split("\\").pop()!.split("/").pop()!;

	const isrc = common.isrc;
	const album = common.album;
	const title = common.title ?? fileName;
	const duration = format.duration;
	const genres = common.genre ?? [];

	const discNumber = common.disk.no ?? undefined;
	const trackNumber = common.track.no ?? undefined;

	const coverImage = selectCover(common.picture);
	let artwork: Maybe<LocalImage>;
	if (coverImage) {
		const localImages = useLocalImages();
		const { data, type } = coverImage;
		const artworkBlob = new Blob([data], { type });
		await localImages.associateImage(id, artworkBlob, {
			maxHeight: 512,
			maxWidth: 512,
		});
		artwork = { id };
	}

	const song: LocalSong = {
		type: "local",
		kind: "song",

		// TODO: Check if format is supported
		available: true,
		// TODO: Try to find a way to classify local files as explicit
		explicit: false,

		id,
		artists,
		album,
		title,
		duration,
		genres,

		artwork,

		data: {
			isrc,
			path,
			discNumber,
			trackNumber,
		},
	};

	if (!album || !common.title) {
		// FIXME: Add proper queue to not block parsing while fetching metadata
		console.log("BEFORE METADATA:", common, format.duration);

		const fileStream = await getFileStream(path);
		const metadata = await metadataService.getMetadata({
			id,
			duration,
			fileName,
			fileStream,
		});

		Object.assign(song, metadata);
		console.log("METADATA:", metadata);
	}

	return song;
}

async function* getLocalSongs(clearCache = false): AsyncGenerator<LocalSong> {
	const localSongs = Array.from(getAllCached<LocalSong>("local", "song"));

	if (clearCache) {
		for (const song of localSongs) {
			removeFromCache(song);
		}
	} else if (localSongs.length) {
		yield* localSongs;
		return;
	}

	// Required for Documents folder to show up in Files
	// NOTE: Hidden file doesn't work
	if (getPlatform() === "ios") {
		try {
			await Filesystem.writeFile({
				path: "/readme.txt",
				data:
					"Place your music files in this directory. They should be automatically recognized by the app.",
				encoding: Encoding.UTF8,
				directory: Directory.Documents,
			});
		} catch (error) {
			console.log("Errored on writing readme.txt:", error instanceof Error ? error.message : error);
		}
	}

	try {
		for await (const { filePath, id } of getSongPaths()) {
			// Skip non-audio file types
			// We ignore this check for android, since it uses MediaStore API
			// and content paths don't have an extension
			if (getPlatform() !== "android" && !audioMimeTypeFromPath(filePath)) continue;

			// Instead of generating UUID and then managing the proper song object
			// We use hashed filePath as an alternative id.
			// We have to hash it to prevent clashing with routes when used as a route parameter.
			const fileId = id ?? String(generateHash(filePath));

			const song = await parseLocalSong(filePath, fileId);
			cache(song);
			yield song;
		}
	} catch (error) {
		console.log("Errored on getSongs:", error instanceof Error ? error.message : error);
	}
}

export class LocalMusicService extends MusicService<"local"> {
	logName = "LocalMusicService";
	logColor = "#ddd480";
	type = "local" as const;
	available = getPlatform() !== "web";

	audio?: HTMLAudioElement;

	constructor() {
		super();
	}

	handleInitialization(): void {
		// TODO: Make an abstract MusicService class that uses HTMLAudioElement
		// 		 Since this is shared between {YouTube,Local}MusicService's, and possibly more in the future
		const audio = new Audio();
		audio.addEventListener("timeupdate", () => {
			this.dispatchEvent(new MusicServiceEvent("timeupdate", audio.currentTime));
		});
		audio.addEventListener("playing", () => {
			this.dispatchEvent(new MusicServiceEvent("playing"));
		});
		audio.addEventListener("ended", () => {
			this.dispatchEvent(new MusicServiceEvent("ended"));
		});
		this.audio = audio;
	}

	handleDeinitialization(): void {}

	handleGetSongsAlbum(song: LocalSong): Maybe<LocalAlbum> {
		const songKey = getKey(song);
		return getAllCached<LocalAlbum>("local", "album").find(({ songs }) =>
			songs.some((albumSong) => albumSong.song === songKey),
		);
	}

	handleGetAlbum(albumId: string): Maybe<LocalAlbum> {
		return getAllCached<LocalAlbum>("local", "album").find(({ id }) => id === albumId);
	}

	handleGetAlbumFromPreview(album: LocalAlbum): LocalAlbum {
		return album;
	}

	#fuses = new Map<SearchFilter, Fuse<SearchResultItem<"local">>>();
	async *handleSearchForItems(
		term: string,
		filter: SearchFilter,
	): AsyncGenerator<SearchResultItem<"local">> {
		let fuse = this.#fuses.get(filter);
		if (!fuse) {
			const data: SearchResultItem<"local">[] = [];
			if (filter === "songs" || filter === "top-results") {
				const songs = await Array.fromAsync(this.getLibrarySongs());
				data.push(...songs);
			}

			if (filter === "artists" || filter === "top-results") {
				const artists = await Array.fromAsync(this.getLibraryArtists());
				data.push(...artists);
			}

			if (filter === "albums" || filter === "top-results") {
				const albums = await Array.fromAsync(this.getLibraryAlbums());
				data.push(...albums);
			}

			// TODO: This might require some messing around with distance/threshold settings to not make it excessively loose
			fuse = new Fuse(data, {
				keys: ["title"] satisfies (keyof SearchResultItem<"local">)[],
				distance: 3,
				threshold: 0.5,
			});
			this.#fuses.set(filter, fuse);
		}

		const results = fuse.search(term);

		for (const { item } of results) {
			yield item;
		}
	}

	handleGetSongFromPreview(songPreview: LocalSong): LocalSong {
		return songPreview;
	}

	async *handleGetLibraryArtists(): AsyncGenerator<LocalArtistPreview | LocalArtist> {
		let iterator = getAllCached<LocalArtistPreview>("local", "artistPreview");
		const first = iterator.next();
		if (first.done) {
			await this.refreshLibraryArtists();
			iterator = getAllCached<LocalArtistPreview>("local", "artistPreview");
		} else {
			yield first.value;
		}

		for (const album of iterator) {
			yield album;
		}
	}

	handleRefreshLibraryArtists(): void {
		const artists: (LocalArtist | Filled<LocalArtistPreview>)[] = [];

		for (const song of getAllCached<LocalSong>("local", "song")) {
			if (!song.artists.length) continue;

			for (const artist of song.artists) {
				const filledArtist = filledDisplayableArtist<"local">(artist);
				if (!("id" in filledArtist)) continue;

				if (filledArtist.kind === "artist") {
					artists.push(filledArtist);
				} else if (filledArtist.kind === "artistPreview") {
					artists.push(filledArtist);
				}
			}
		}

		for (const [artist] of Map.groupBy(artists, (artist) => artist.id).values()) {
			cache(artist!);
		}
	}

	async handleGetArtist(id: string): Promise<Maybe<Artist<"local">>> {
		const cached = getCached("artist", id);
		if (cached) {
			return cached;
		}

		const preview = getCached("artistPreview", id);
		if (!preview) {
			return;
		}

		const artist: LocalArtist = {
			id: preview.id,
			type: "local",
			kind: "artist",

			title: preview.title,

			albums: [],
			songs: [],
		};

		const itemHasCurrentArtist = (itemArtist: LocalDisplayableArtist): boolean => {
			const { title } = filledDisplayableArtist(itemArtist);
			return title === artist.title;
		};

		for (const song of getAllCached<LocalSong>("local", "song")) {
			if (song.artists.some(itemHasCurrentArtist)) {
				artist.songs.push(getKey(song));
			}
		}

		for await (const album of this.handleGetLibraryAlbums()) {
			if (album.artists.some(itemHasCurrentArtist)) {
				artist.albums.push(getKey(album));
			}
		}

		return cache(artist);
	}

	*handleGetArtistsSongs(
		artist: LocalArtist | Filled<LocalArtist>,
	): Generator<LocalSong | LocalSongPreview> {
		for (const song of artist.songs) {
			if (typeof song === "object") {
				yield song;
				continue;
			}

			const cached = getCachedFromKey(song);
			if (cached) yield cached;
		}
	}

	async *handleGetLibraryAlbums(): AsyncGenerator<LocalAlbum> {
		let iterator = getAllCached<LocalAlbum>("local", "album");
		const first = iterator.next();
		if (first.done) {
			await this.refreshLibraryAlbums();
			iterator = getAllCached<LocalAlbum>("local", "album");
		} else {
			yield first.value;
		}

		for (const album of iterator) {
			yield album;
		}
	}

	handleRefreshLibraryAlbums(): void {
		// First we cleanup songs from albums, in case some were removed
		// This also allows us to then remove albums that are empty
		const localAlbums = Array.from(getAllCached<LocalAlbum>("local", "album"));

		for (const album of localAlbums) {
			album.songs.length = 0;
		}

		for (const song of getAllCached<LocalSong>("local", "song")) {
			if (!song.album) continue;

			const discSong: LocalAlbumSong = {
				song: getKey(song),
				discNumber: song.data.discNumber,
				trackNumber: song.data.trackNumber,
			};

			// Find all albums that match the songs album title and has at least 1 shared artist
			const possibleAlbums = localAlbums.filter((album) => {
				if (album.title !== song.album) return false;

				return album.artists.some((artist) => {
					const albumArtist = filledDisplayableArtist(artist);
					return song.artists.find(
						(songArtist) => filledDisplayableArtist(songArtist).title == albumArtist.title,
					);
				});
			});

			// If no such albums exist, create a new one
			if (!possibleAlbums.length) {
				const album: LocalAlbum = cache({
					type: "local",
					kind: "album",
					id: generateUUID(),
					title: song.album,
					songs: [discSong],
					artists: toRaw(song.artists),
					artwork: toRaw(song.artwork),
				});

				localAlbums.push(album);
				continue;
			}

			for (const album of possibleAlbums) {
				album.songs.push(discSong);
			}
		}

		for (const [i, album] of localAlbums.entries()) {
			// Remove albums with no songs
			if (album.songs.length === 0) {
				album.songs.splice(i, 1);
				continue;
			}

			// Sort album songs so they match the disc and track order
			album.songs.sort(
				(a, b) =>
					(a.discNumber ?? 0) - (b.discNumber ?? 0) || (a.trackNumber ?? 0) - (b.trackNumber ?? 0),
			);
		}
	}

	async *handleGetLibrarySongs(): AsyncGenerator<LocalSong> {
		yield* getLocalSongs();
	}

	async handleRefreshLibrarySongs(): Promise<void> {
		this.#fuses.clear();
		await Array.fromAsync(getLocalSongs(true));
	}

	handleGetSong(songId: string): Maybe<LocalSong> {
		const cached = getCached("song", songId);
		if (cached) return cached;

		const song = getAllCached<LocalSong>("local", "song").find((song) => song.id === songId);
		return song && cache(song);
	}

	async handleRefreshSong(song: LocalSong): Promise<LocalSong> {
		const filePath = song.data.path;
		const refreshed = await parseLocalSong(filePath, song.id);
		return cache(refreshed);
	}

	async handlePlay(): Promise<void> {
		const song = this.song!;
		const path = song.data.path;

		const stream = await getFileStream(path);
		const buffer = await new Response(stream).arrayBuffer();
		const blob = new Blob([buffer], { type: audioMimeTypeFromPath(path) });
		const url = URL.createObjectURL(blob);

		const audio = this.audio;
		audio!.src = url;

		try {
			await audio!.play();
		} catch (error) {
			// Someone skipped or stopped the song while it was still trying to play it, let it slide
			if (error instanceof Error && error.name === "AbortError") {
				return;
			}
		}
	}

	async handleResume(): Promise<void> {
		await this.audio?.play?.();
	}

	handlePause(): void {
		this.audio?.pause?.();
	}

	handleStop(): void {
		if (this.audio) {
			this.audio.pause();
			URL.revokeObjectURL(this.audio.src);
		}
	}

	handleSeekToTime(timeInSeconds: number): void {
		this.audio!.currentTime = timeInSeconds;
	}

	handleSetVolume(volume: number): void {
		this.audio!.volume = volume;
	}
}
