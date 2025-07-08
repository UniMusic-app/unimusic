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

import { generateHash, generateUUID } from "@/utils/crypto";
import { getPlatform } from "@/utils/os";
import { audioMimeTypeFromPath, getFileStream, getSongPaths } from "@/utils/path";
import { Maybe } from "@/utils/types";
import { Directory, Encoding, Filesystem } from "@capacitor/filesystem";
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

export class LocalMusicService extends MusicService<"local"> {
	logName = "LocalMusicService";
	logColor = "#ddd480";
	type = "local" as const;
	available = getPlatform() !== "web";
	description = "Listen to your local collection of music.";

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

	async #parseLocalSong(path: string, id: string): Promise<LocalSong> {
		await this.initialize();

		const mimeType = audioMimeTypeFromPath(path);
		const stream = await getFileStream(path);
		const metadata = await parseWebStream(
			stream,
			{ path, mimeType },
			{ duration: true, skipPostHeaders: true },
		);

		const { common, format } = metadata;

		const artists: LocalDisplayableArtist[] = [];
		if (common.artists?.length) {
			for (let i = 0; i < common.artists.length; ++i) {
				const title = common.artists[i]!;
				const artistPreview = cache<LocalArtistPreview>({
					type: "local",
					kind: "artistPreview",
					id: title,
					title,
				});
				artists.push(getKey(artistPreview));
			}
		}

		const title = common.title;
		const isrc = common.isrc;
		const album = common.album;
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
			await localImages.associateImage(id, artworkBlob);
			artwork = { id };
		}

		const available = mimeType ? !!this.audio!.canPlayType(mimeType) : true;
		if (!mimeType) {
			this.log(`Could not get mimeType from path ${path}, availability might be inaccurate`);
		}

		return {
			type: "local",
			kind: "song",

			available,
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
				hasMetadata: !!common.title,
				includedMetadata: !!common.title,
			},
		};
	}

	async *#parseLocalSongs(): AsyncGenerator<LocalSong> {
		const localSongs = new Map(
			getAllCached<LocalSong>("local", "song").map((song) => [song.data.path, song]),
		);

		console.log(localSongs);

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
			const missingMetadata: LocalSong[] = [];
			for await (const { filePath, id } of getSongPaths()) {
				// Don't reparse songs that have been already parsed and have metadata
				const localSong = localSongs.get(filePath);
				if (localSong?.data?.hasMetadata) {
					this.log("Already parsed", filePath);
					yield localSong;
					localSongs.delete(filePath);
					continue;
				}

				// Skip non-audio file types
				// We ignore this check for android, since it uses MediaStore API
				// and content paths don't have an extension
				if (getPlatform() !== "android" && !audioMimeTypeFromPath(filePath)) continue;

				// Instead of generating UUID and then managing the proper song object
				// We use hashed filePath as an alternative id.
				// We have to hash it to prevent clashing with routes when used as a route parameter.
				const fileId = id ?? String(generateHash(filePath));

				this.log("Parsing", filePath);
				const song = await this.#parseLocalSong(filePath, fileId);

				if (!song.data.hasMetadata) {
					// We still yield the songs so users can immediately interact with them
					// Metadata will progressively be updated in the background
					missingMetadata.push(song);
				}

				cache(song);
				yield song;
				localSongs.delete(filePath);
			}

			if (this.services.canGetMetadata) {
				const promises: Promise<LocalSong>[] = [];
				for (const song of missingMetadata) {
					const fileName = song.data.path.split("\\").pop()!.split("/").pop()!;

					let songTitle: string | undefined;
					let songArtists: string[] | undefined;

					// Try to guess title and artists of a song from its fileName
					// Patterns are sorted by their "specificity" – how narrowly can it determine a specific pattern
					//
					//  Possible groups:
					//  - title - Song Title
					//  - artists - Song Artists (unparsed)
					//  - feat - Additional artists that have been noted separately (unparsed)
					//  - extension - File extension
					const fileNamePatterns = [
						// Move (feat. Camila Cabello) - Adam Port, Stryv, Malachiii, Orso (Official Visualizer)
						/^(?<title>.+?)(\s*\((feat|ft)\.\s*(?<feat>.+?)\))\s+[-—–]\s+(?<artists>.+?)(\s*[([].+?[)\]]).*?(?<extension>\..+)?$/,

						// Billion Dollar Bitch (feat. Yung Baby Tate) (Swizzymack Remix) [SNq8umw9K2I].webm
						/^(?<title>[^-—–]+?)\s+(\((feat|ft)\.\s*(?<feat>.+?)\))[^-—–]+?\.(?<extension>.+)/,

						// Shotgun Willy - Fuego feat. TRAQULA (Lyric Video) [3LIisa4u0Vc].webm
						/(?<artists>.+?)\s+[-—–]\s+(?<title>.+?)((\s+(feat|ft)\.\s*(?<feat>.+?))(\s+[([].+?[)\]]))+(.*(?<extension>\..+)?)?/,

						// Michael Jackson - Billie Jean (Official Video)
						// Michael Jackson — Billie Jean (lyrics) [HD]
						// Post Malone - I Had Some Help (feat. Morgan Wallen) (Official Video)
						// BABY GRAVY - Nightmare on Peachtree St. (feat. Freddie Dredd) Official Lyric Video [faK9ml3y950].webm
						/(?<artists>.+?)\s+[-—–]\s+(?<title>.+?)((\s+\((feat|ft)\.\s*(?<feat>.+?)\))|(\s+[([].+?[)\]]))+(.*(?<extension>\..+))?/,

						// Michael Jackson - Billie Jean
						// Michael Jackson - Billie Jean.wav
						/(?<artists>.+?)\s+[-—–]\s+(?<title>.+?)(\.(?<extension>.+))?$/,

						// いめ44「遊び」feat. 歌愛ユキ
						// いめ44「遊び」feat. 歌愛ユキ.mp3
						/(?<title>.+?)\s*(feat|ft)\.\s*(?<artists>.+?)(\.(?<extension>.+))?$/,

						// Billie Jean
						// Billie Jean (Official Video)
						/^(?<title>.+?)((\s*([([].*)*\s*(?<extension>\..+))|([([].*))?$/,
					];

					// artist_a, artist_b & artist_c
					// artist_a & artist_b & artist_c
					// artist_a x artist_b x artist_c
					const artistsPattern = /(?:\s+(?:&|x)\s+)|(?:\s*,\s+)/;

					for (const pattern of fileNamePatterns) {
						const match = fileName.match(pattern);
						if (!match) continue;

						const { title, artists, feat } = match.groups!;

						const parsedArtists = [];
						if (artists) parsedArtists.push(...artists.split(artistsPattern));
						if (feat) parsedArtists.push(...feat.split(artistsPattern));

						songTitle = title;
						songArtists = parsedArtists;
						break;
					}

					this.log("Missing metadata, trying to get one for", song.data.path);

					if (!songTitle) {
						this.log("Failed to guess song title from", fileName);
						continue;
					}

					this.log(`Guessed title and artists for ${song.data.path}:`, songTitle, songArtists);

					song.title = songTitle;
					song.artists = songArtists?.map((artist) => ({ title: artist })) ?? [];
					cache(song);

					const promise = this.services
						.getMetadata({
							id: song.id,
							duration: song.duration,
							title: songTitle,
							artists: songArtists,
							filePath: song.data.path,
						})
						.then((metadata) => {
							// TODO: Allow searching for partial missing metadata

							if (!metadata) {
								song.data.hasMetadata = false;
								return cache(song);
							}

							if (metadata.title) song.title = metadata.title;
							if (metadata.album) song.album = metadata.album;
							if (metadata.artists) {
								song.artists = metadata.artists.map((artist) => {
									const artistPreview = cache<LocalArtistPreview>({
										type: "local",
										kind: "artistPreview",
										id: artist.id ?? artist.title,
										title: artist.title,
									});

									return getKey(artistPreview);
								});
							}
							if (metadata.genres) song.genres = metadata.genres;
							if (metadata.isrc) song.data.isrc = metadata.isrc;
							if (metadata.discNumber) song.data.discNumber = metadata.discNumber;
							if (metadata.trackNumber) song.data.trackNumber = metadata.trackNumber;
							if (metadata.artwork) song.artwork = metadata.artwork;

							song.data.hasMetadata = true;

							return cache(song);
						});

					promises.push(promise);
				}

				yield* promises;
			}

			// Remove songs that have been deleted
			for (const [path, song] of localSongs) {
				this.log("File no longer exists, removing metadata:", path);
				removeFromCache(song);
			}

			this.log("Finished parsing songs");
		} catch (error) {
			this.log("Failed to parse songs");
			console.error(error);
		}

		await this.refreshLibraryAlbums();
	}

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

		for (const album of localAlbums.values()) {
			// Remove albums with no songs
			if (album.songs.length === 0) {
				removeFromCache(album);
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
		let empty = true;
		for (const song of getAllCached<LocalSong>("local", "song")) {
			yield song;
			empty = false;
		}

		if (empty) yield* this.#parseLocalSongs();
	}

	async handleRefreshLibrarySongs(): Promise<void> {
		this.#fuses.clear();
		await Array.fromAsync(this.#parseLocalSongs());
	}

	handleGetSong(songId: string): Maybe<LocalSong> {
		const cached = getCached("song", songId);
		if (cached) return cached;

		const song = getAllCached<LocalSong>("local", "song").find((song) => song.id === songId);
		return song && cache(song);
	}

	async handleRefreshSong(song: LocalSong): Promise<LocalSong> {
		const filePath = song.data.path;
		const refreshed = await this.#parseLocalSong(filePath, song.id);
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
