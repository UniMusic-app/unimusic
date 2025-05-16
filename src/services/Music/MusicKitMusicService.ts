import { alertController } from "@ionic/vue";

import { LocalImage, useLocalImages } from "@/stores/local-images";

import { MusicKitAuthorizationService } from "@/services/Authorization/MusicKitAuthorizationService";
import {
	MusicService,
	MusicServiceEvent,
	SearchFilter,
	SearchResultItem,
	SilentError,
} from "@/services/Music/MusicService";

import { generateUUID } from "@/utils/crypto";
import { Maybe } from "@/utils/types";

import {
	Album,
	AlbumKey,
	AlbumPreview,
	AlbumPreviewKey,
	AlbumSong,
	Artist,
	ArtistKey,
	ArtistPreview,
	cache,
	DisplayableArtist,
	Filled,
	generateCacheMethod,
	getKey,
	Playlist,
	Song,
	SongKey,
	SongPreview,
	SongPreviewKey,
} from "./objects";

const getCached = generateCacheMethod("musickit");

type MusicKitAlbum = Album<"musickit">;
type MusicKitAlbumKey = AlbumKey<"musickit">;
type MusicKitAlbumPreviewKey = AlbumPreviewKey<"musickit">;
type MusicKitAlbumPreview = AlbumPreview<"musickit">;
type MusicKitAlbumSong = AlbumSong<"musickit">;
type MusicKitArtist = Artist<"musickit">;
type MusicKitArtistPreview = ArtistPreview<"musickit">;
type _MusicKitArtistKey = ArtistKey<"musickit">;
type MusicKitSong = Song<"musickit">;
type MusicKitSongKey = SongKey<"musickit">;
type MusicKitSongPreview = SongPreview<"musickit", true>;
type MusicKitSongPreviewKey = SongPreviewKey<"musickit">;
type MusicKitDisplayableArtist = DisplayableArtist<"musickit">;

export function extractDisplayableArtists(
	artists: MusicKit.Artists[] | Maybe<string>,
): MusicKitDisplayableArtist[] {
	if (!artists) {
		return [];
	} else if (typeof artists === "string") {
		return [{ title: artists }];
	}

	const keys: MusicKitDisplayableArtist[] = [];
	for (const artist of artists) {
		if (!artist.attributes?.name) continue;

		const cached = getCached("artist", artist.id) ?? getCached("artistPreview", artist.id);
		keys.push(cached ? getKey(cached) : getKey(cache(musicKitArtistPreview(artist))));
	}
	return keys;
}

export function extractCatalogId(
	data?:
		| string
		| MusicKit.Songs
		| MusicKit.LibrarySongs
		| MusicKit.MusicVideos
		| MusicKit.LibrarySongsRelationships,
): Maybe<string> {
	if (!data) {
		return;
	}

	if (typeof data === "string") {
		if (musicKitIdType(data) === "catalog") {
			return data;
		}
		return;
	}

	if ("id" in data) {
		if (musicKitIdType(data.id) === "catalog") return data.id;
		return;
	}

	if ("catalog" in data) {
		const song = data.catalog?.data?.[0];
		if (song?.id && musicKitIdType(song.id) === "catalog") {
			return song.id;
		}
	}
}

export function extractArtistNames(artists: MusicKit.Artists[] | Maybe<string>): string[] {
	if (!Array.isArray(artists)) {
		return typeof artists === "string" ? [artists] : [];
	}

	return artists
		.map((artists) => artists.attributes?.name)
		.filter((artist) => typeof artist === "string");
}

export function extractGenres(genres: MusicKit.Genres[] | Maybe<string[]>): string[] {
	if (!genres) {
		return [];
	}

	return genres
		.map((genre) => (typeof genre === "string" ? genre : genre.attributes?.name))
		.filter((genre) => typeof genre === "string");
}

export async function extractArtwork(id: string, artwork: MusicKit.Artwork): Promise<LocalImage>;
export async function extractArtwork(
	id: string,
	artwork?: MusicKit.Artwork,
): Promise<Maybe<LocalImage>>;
export async function extractArtwork(
	id: string,
	artwork?: MusicKit.Artwork,
): Promise<Maybe<LocalImage>> {
	if (!artwork) return;

	const localImages = useLocalImages();
	const artworkUrl = MusicKit.formatArtworkURL(artwork, 256, 256);
	try {
		const artworkBlob = await (await fetch(artworkUrl)).blob();
		await localImages.associateImage(id, artworkBlob);
		return { id };
	} catch {
		// TODO: Remove this after Apple fixes artwork CORS issues
		return {
			url: artworkUrl,
			style: {
				fgColor: `#${artwork.textColor1 ?? "fff"}`,
				bgColor: `#${artwork.bgColor ?? "000"}`,
			},
		};
	}
}

export function musicKitSongPreview(
	song: MusicKit.Songs | MusicKit.LibrarySongs | MusicKit.MusicVideos,
): MusicKitSongPreview {
	const { id, attributes, relationships } = song;

	let artwork: Maybe<LocalImage>;
	if (attributes?.artwork) {
		const artworkUrl = MusicKit.formatArtworkURL(attributes.artwork, 256, 256);
		artwork = {
			url: artworkUrl,
			style: { bgColor: `#${attributes.artwork.bgColor ?? "000"}` },
		};
	}

	const artists = extractDisplayableArtists(relationships?.artists?.data ?? attributes?.artistName);
	const genres = extractGenres(relationships?.genres?.data ?? attributes?.genreNames);
	const explicit = song.attributes?.contentRating === "explicit";
	const available = typeof song.attributes?.playParams === "object";

	const catalogId = extractCatalogId(
		relationships && "catalog" in relationships ? relationships : song,
	);

	return {
		id,
		type: "musickit",
		kind: "songPreview",

		artists,

		title: attributes?.name,
		album: attributes?.albumName,
		duration: attributes?.durationInMillis && attributes?.durationInMillis / 1000,
		genres,

		explicit,
		available,

		artwork,

		data: {
			catalogId,
			musicVideo: song.type === "music-videos",
		},
	};
}

export async function musicKitPreviewToSong(
	songPreview: MusicKitSongPreview,
): Promise<MusicKitSong> {
	const { id, title, album, artists, duration, available = false, explicit = false } = songPreview;

	const genres = songPreview.genres ?? [];
	let artwork: Maybe<LocalImage>;
	if (songPreview.artwork) {
		const localImages = useLocalImages();
		try {
			const response = await fetch(songPreview.artwork.url!);
			const artworkBlob = await response.blob();
			await localImages.associateImage(id, artworkBlob);
			artwork = { id };
		} catch {
			artwork = songPreview.artwork;
		}
	}

	const catalogId = extractCatalogId(songPreview.data?.catalogId ?? id);

	return {
		type: "musickit",
		kind: "song",
		id,

		artists,
		genres,

		title,
		album,
		duration,

		explicit,
		available,

		artwork,

		data: {
			catalogId,
			musicVideo: songPreview.data?.musicVideo,
		},
	};
}

export async function musicKitSong(
	song: MusicKit.Songs | MusicKit.LibrarySongs | MusicKit.MusicVideos,
): Promise<MusicKitSong> {
	const { id, attributes, relationships } = song;

	const artwork = await extractArtwork(id, attributes?.artwork);
	const artists = extractDisplayableArtists(relationships?.artists?.data ?? attributes?.artistName);
	const genres = extractGenres(relationships?.genres?.data ?? attributes?.genreNames);
	const explicit = song.attributes?.contentRating === "explicit";
	const available = typeof song.attributes?.playParams === "object";

	const catalogId = extractCatalogId(
		relationships && "catalog" in relationships ? relationships : song,
	);

	return cache<MusicKitSong>({
		type: "musickit",
		kind: "song",
		id,

		artists,
		genres,

		explicit,
		available,

		title: attributes?.name,
		album: attributes?.albumName,
		duration: attributes?.durationInMillis && attributes?.durationInMillis / 1000,

		artwork,

		data: {
			catalogId,
			musicVideo: song.type === "music-videos",
		},
	});
}

export async function musicKitAlbum(album: MusicKit.Albums): Promise<MusicKitAlbum> {
	const { id, attributes, relationships } = album;

	const title = attributes?.name ?? "Unknown title";
	const artwork = await extractArtwork(id, attributes?.artwork);
	const artists = extractDisplayableArtists(relationships?.artists?.data ?? attributes?.artistName);

	const songs: MusicKitAlbumSong[] = [];
	const tracks = relationships?.tracks?.data;
	if (tracks) {
		for (const track of tracks) {
			const cached = getCached("song", track.id) ?? getCached("songPreview", track.id);
			const songPreview: MusicKitSongPreview = cached ?? cache(musicKitSongPreview(track));

			songs.push({
				discNumber: track.attributes?.discNumber,
				trackNumber: Number(track.attributes?.trackNumber),
				song: getKey(songPreview),
			});
		}
	}

	return cache<MusicKitAlbum>({
		type: "musickit",
		kind: "album",
		id,

		title,
		artwork,

		artists,
		songs,
	});
}

export function musicKitAlbumPreview(album: MusicKit.Albums): MusicKitAlbumPreview {
	const { id, attributes, relationships } = album;

	const title = attributes?.name ?? "Unknown title";
	const artists = extractDisplayableArtists(relationships?.artists?.data ?? attributes?.artistName);

	let artwork: Maybe<LocalImage>;
	if (attributes?.artwork) {
		const artworkUrl = MusicKit.formatArtworkURL(attributes.artwork, 256, 256);
		artwork = {
			url: artworkUrl,
			style: { bgColor: `#${attributes.artwork.bgColor ?? "000"}` },
		};
	}

	return {
		id,
		type: "musickit",
		kind: "albumPreview",

		title,
		artists,
		artwork,
	};
}

export function musicKitArtistPreview(
	artist: MusicKit.Artists | MusicKit.LibraryArtists,
): MusicKitArtistPreview {
	const { id, attributes, relationships } = artist;
	const catalogArtist =
		relationships && "catalog" in relationships
			? relationships?.catalog?.data?.[0]
			: (artist as MusicKit.Artists);

	let artwork: Maybe<LocalImage>;
	const artistArtwork = catalogArtist?.attributes?.artwork;
	if (artistArtwork) {
		const artworkUrl = MusicKit.formatArtworkURL(artistArtwork, 256, 256);
		artwork = {
			url: artworkUrl,
			style: { bgColor: `#${artistArtwork.bgColor ?? "000"}` },
		};
	}

	return {
		id,
		type: "musickit",
		kind: "artistPreview",

		title: (attributes?.name ?? catalogArtist?.attributes?.name)!,
		artwork,
	};
}

export async function musicKitArtist(
	artist: MusicKit.Artists | MusicKit.LibraryArtists,
): Promise<MusicKitArtist> {
	const { id, attributes, relationships } = artist;

	const catalogArtist =
		artist.type === "library-artists" ? artist.relationships?.catalog?.data?.[0] : artist;

	const artwork = await extractArtwork(id, catalogArtist?.attributes?.artwork);

	const albums: (MusicKitAlbumKey | MusicKitAlbumPreviewKey)[] = [];
	const catalogAlbums = relationships?.albums?.data;
	if (catalogAlbums?.length) {
		for (const album of catalogAlbums) {
			const albumPreview =
				getCached("album", album.id) ??
				getCached("albumPreview", album.id) ??
				cache(musicKitAlbumPreview(album));

			albums.push(getKey(albumPreview));
		}
	}

	const songs: (MusicKitSongKey | MusicKitSongPreviewKey)[] = [];
	if (relationships && "songs" in relationships) {
		for (const song of relationships.songs.data) {
			const songPreview =
				getCached("song", song.id) ??
				getCached("songPreview", song.id) ??
				cache(musicKitSongPreview(song));

			songs.push(getKey(songPreview));
		}
	}

	return {
		id,
		type: "musickit",
		kind: "artist",

		title: (attributes?.name ?? catalogArtist?.attributes?.name)!,
		artwork,

		albums,
		songs,
	};
}

export function musicKitIdType(id: string): "library" | "catalog" {
	if (!isNaN(Number(id))) {
		return "catalog";
	}
	return "library";
}

// TODO: Warning/Note if user has no paid Apple Music Subscription but tried to enable it
// TODO: Warning/Note if user has declined Apple Music permission
export class MusicKitMusicService extends MusicService<"musickit"> {
	logName = "MusicKitMusicService";
	logColor = "#cc80dd";
	type = "musickit" as const;
	available = true;

	music?: MusicKit.MusicKitInstance;
	authorization = new MusicKitAuthorizationService();

	constructor() {
		super();
	}

	async *handleGetSearchHints(term: string): AsyncGenerator<string> {
		if (!term) return [];

		const response = await this.music!.api.music<{ results: { terms: string[] } }>(
			"/v1/catalog/{{storefrontId}}/search/hints",
			{ term },
		);

		const { terms } = response.data.results;
		yield* terms;
	}

	async *handleGetLibraryArtists(options?: {
		signal?: AbortSignal;
	}): AsyncGenerator<MusicKitArtistPreview | MusicKitArtist> {
		const response = await this.music!.api.music<
			MusicKit.LibraryArtistsResponse,
			MusicKit.LibraryArtistsQuery
		>(`/v1/me/library/artists`, {
			include: ["catalog"],
		});

		const artists = response.data.data;
		if (!artists.length) return;

		for (const artist of artists) {
			if (options?.signal?.aborted) return;
			yield getCached("artist", artist.id) ??
				getCached("artistPreview", artist.id) ??
				cache(musicKitArtistPreview(artist));
		}
	}

	async handleGetArtist(id: string): Promise<Maybe<Artist<"musickit">>> {
		const cachedArtist = getCached("artist", id);
		if (cachedArtist) return cachedArtist;

		const idType = musicKitIdType(id);

		let response: { data: MusicKit.ArtistsResponse | MusicKit.LibraryArtistsResponse };
		if (idType === "catalog") {
			response = await this.music!.api.music<MusicKit.ArtistsResponse, MusicKit.ArtistsQuery>(
				`/v1/catalog/{{storefrontId}}/artists/${id}`,
				{ include: ["albums", "songs"] },
			);
		} else {
			response = await this.music!.api.music<
				MusicKit.LibraryArtistsResponse,
				MusicKit.LibraryArtistsQuery
			>(`/v1/me/library/artists/${id}`, { include: ["catalog", "albums"] });
		}

		const artist = response.data?.data?.[0];
		if (!artist) return;

		return cache(await musicKitArtist(artist));
	}

	async *handleGetArtistsSongs(
		artist: MusicKitArtist | Filled<MusicKitArtist>,
	): AsyncGenerator<MusicKitSong | MusicKitSongPreview> {
		const music = this.music!;
		const query = { limit: 25 };
		let response = await music.api.music<MusicKit.SongsResponse>(
			`/v1/catalog/{{storefrontId}}/artists/${artist.id}/view/top-songs`,
			query,
		);

		while (true) {
			if (!response?.data?.data) {
				break;
			}

			for (const song of response.data.data) {
				const songPreview =
					getCached("song", song.id) ??
					getCached("songPreview", song.id) ??
					cache(musicKitSongPreview(song));

				yield songPreview;
			}

			if (!response.data.next) {
				break;
			}

			response = await music.api.music(response.data.next, query);
		}
	}

	async *handleGetLibraryAlbums(options?: {
		signal?: AbortSignal;
	}): AsyncGenerator<MusicKitAlbumPreview> {
		const response = await this.music!.api.music<MusicKit.AlbumsResponse, MusicKit.AlbumsQuery>(
			`/v1/me/library/albums`,
			{ include: ["artists"] },
		);

		const albums = response.data.data;
		if (!albums.length) return;

		for (const album of albums) {
			if (options?.signal?.aborted) return;
			yield cache(musicKitAlbumPreview(album));
		}
	}

	async handleGetSongsAlbum(song: MusicKitSong, useCache = true): Promise<Maybe<MusicKitAlbum>> {
		let { catalogId } = song.data;

		// In case cached version doesn't have catalogId, get it
		// TODO: Prevent overriding valid cached instances that contain more information
		if (!catalogId) {
			const refreshed = await this.refreshSong(song);
			catalogId = refreshed!.data.catalogId;
		}

		// We want to retrieve catalog album
		let response: { data: MusicKit.AlbumsResponse };
		if (song.data.musicVideo) {
			response = await this.music!.api.music<MusicKit.AlbumsResponse, MusicKit.AlbumsQuery>(
				`/v1/catalog/{{storefrontId}}/music-videos/${catalogId}/albums`,
				{ include: ["artists", "tracks"] },
			);
		} else {
			response = await this.music!.api.music<MusicKit.AlbumsResponse, MusicKit.AlbumsQuery>(
				`/v1/catalog/{{storefrontId}}/songs/${catalogId}/albums`,
				{ include: ["artists", "tracks"] },
			);
		}

		const album = response.data?.data?.[0];
		if (!album) return;

		if (useCache) {
			const cachedAlbum = getCached("album", album.id);
			if (cachedAlbum) return cachedAlbum;
		}

		return cache(await musicKitAlbum(album));
	}

	async handleGetAlbum(id: string, useCache = true): Promise<Maybe<MusicKitAlbum>> {
		if (useCache) {
			const cachedAlbum = getCached("album", id);
			if (cachedAlbum) return cachedAlbum;
		}

		const idType = musicKitIdType(id);

		const response = await this.music!.api.music<MusicKit.AlbumsResponse, MusicKit.AlbumsQuery>(
			idType === "catalog"
				? `/v1/catalog/{{storefrontId}}/albums/${id}`
				: `/v1/me/library/albums/${id}`,
			{ include: ["artists", "tracks"] },
		);

		const album = response.data?.data?.[0];
		if (!album) return;

		return cache(await musicKitAlbum(album));
	}

	async handleGetAlbumFromPreview(albumPreview: MusicKitAlbumPreview): Promise<MusicKitAlbum> {
		const album = await this.getAlbum(albumPreview.id);
		if (!album) {
			throw new Error(`Failed to find album for albumPreview: ${albumPreview.id}`);
		}
		return album;
	}

	async handleGetPlaylist(url: URL): Promise<Maybe<Playlist>> {
		let endpoint: string | undefined;

		const { pathname } = url;

		if (!url.origin.endsWith("music.apple.com")) {
			return;
		}

		/// e.g.
		// https://music.apple.com/library/playlist/<libraryPlaylistId>
		if (pathname.includes("library")) {
			endpoint = "/v1/me/library/playlists";
		} else {
			// https://music.apple.com/pl/playlist/heavy-rotation-mix/<storefrontPlaylistId>
			// https://music.apple.com/pl/playlist/get-up-mix/<storefrontPlaylistId>
			endpoint = "/v1/catalog/{{storefrontId}}/playlists";
		}

		const idStartIndex = pathname.lastIndexOf("/");
		if (idStartIndex === -1) {
			return;
		}

		const musicKitId = pathname.slice(idStartIndex + 1);
		if (!musicKitId) {
			return;
		}

		const response = await this.music!.api.music<MusicKit.PlaylistsResponse, MusicKit.PlaylistsQuery>(
			`${endpoint}/${musicKitId}`,
			{
				extend: ["editorialArtwork", "editorialVideo", "offers"],
				include: ["tracks"],
			},
		);
		const playlist = response.data.data?.[0];

		if (!playlist) {
			return;
		}

		const id = generateUUID();
		const { attributes } = playlist;
		const title = attributes?.name ?? "Unknown title";

		let artwork: Maybe<LocalImage>;
		if (attributes?.artwork) {
			const localImages = useLocalImages();
			const artworkUrl = MusicKit.formatArtworkURL(attributes.artwork, 256, 256);
			const artworkBlob = await (await fetch(artworkUrl)).blob();
			await localImages.associateImage(id, artworkBlob);
			artwork = { id };
		}

		const tracks = playlist.relationships?.tracks.data ?? [];
		const songs = await Promise.all(
			tracks.map(async (track) => {
				const song = await musicKitSong(track);
				cache(song);
				return getKey(song);
			}),
		);

		return cache<Playlist>({
			type: "unimusic",
			kind: "playlist",
			id,
			title,
			artwork,
			songs,
		});
	}

	async *handleSearchForItems(
		term: string,
		filter: SearchFilter,
	): AsyncGenerator<SearchResultItem<"musickit">> {
		const music = this.music!;
		const query: MusicKit.CatalogSearchQuery = {
			term,
			types: [],
			limit: 25,
		};

		switch (filter) {
			case "top-results":
				query.types.push("songs", "music-videos", "artists", "albums");
				query.with = ["topResults"];
				break;
			case "songs":
				query.types.push("songs", "music-videos");
				break;
			case "albums":
				query.types.push("albums");
				break;
			case "artists":
				query.types.push("artists");
				break;
		}

		let response = await music.api.music<MusicKit.SearchResponse, MusicKit.CatalogSearchQuery>(
			"/v1/catalog/{{storefrontId}}/search",
			query,
		);

		while (true) {
			const { topResults, songs, albums, artists } = response.data.results;
			const items = topResults ?? songs ?? albums ?? artists;

			if (!items?.data) break;

			for (const item of items.data) {
				switch (item.type) {
					case "music-videos":
					case "songs": {
						yield getCached("song", item.id) ??
							getCached("songPreview", item.id) ??
							cache(musicKitSongPreview(item));
						break;
					}
					case "albums": {
						yield getCached("album", item.id) ??
							getCached("albumPreview", item.id) ??
							cache(musicKitAlbumPreview(item));
						break;
					}
					case "artists": {
						yield getCached("artist", item.id) ??
							getCached("artistPreview", item.id) ??
							cache(musicKitArtistPreview(item));
						break;
					}
				}
			}

			if (!("next" in items)) {
				break;
			}

			response = await music.api.music(items.next as string, query);
		}
	}

	async handleGetSongFromPreview(songPreview: MusicKitSongPreview): Promise<MusicKitSong> {
		return cache(await musicKitPreviewToSong(songPreview));
	}

	async handleRefreshLibrarySongs(): Promise<void> {
		// TODO: Unimplemented
	}

	async handleGetSong(songId: string, useCache = true): Promise<MusicKitSong> {
		if (useCache) {
			const cachedSong = getCached("song", songId);
			if (cachedSong) return cachedSong;
		}

		const idType = musicKitIdType(songId);

		const response = await this.music!.api.music<
			MusicKit.SongsResponse | MusicKit.LibrarySongsResponse
		>(
			idType === "catalog"
				? `/v1/catalog/{{storefrontId}}/songs/${songId}`
				: `/v1/me/library/songs/${songId}`,
			{ include: ["artists", "catalog"] },
		);

		const [responseSong] = response.data.data;
		if (!responseSong) {
			throw new Error(`Failed to find a song with id: ${songId}`);
		}

		return cache(await musicKitSong(responseSong));
	}

	async handleRefreshSong(song: MusicKitSong): Promise<MusicKitSong> {
		return await this.handleGetSong(song.id, false);
	}

	async *handleGetLibrarySongs(): AsyncGenerator<MusicKitSong> {
		const response = await this.music!.api.music<
			MusicKit.LibrarySongsResponse,
			MusicKit.LibrarySongsQuery
		>("/v1/me/library/songs", { limit: 25, include: ["catalog"] });

		for (const song of response.data.data) {
			// Filter out songs that cannot be played
			if (!song.attributes?.playParams) continue;
			yield getCached("song", song.id) ?? cache(musicKitSong(song));
		}
	}

	async handleInitialization(): Promise<void> {
		while (!this.authorization.authorized.value) {
			const alert = await alertController.create({
				header: "You need to authorize MusicKit",
				subHeader: this.logName,
				message: "To use MusicKit you have to be authorized",
				buttons: [
					{ text: "Authorize", role: "confirm" },
					{ text: "Disable", role: "destructive" },
				],
			});

			await alert.present();
			const { role } = await alert.onDidDismiss();
			if (role === "confirm") {
				await this.authorization.authorize();
			} else {
				await this.disable();
				throw new SilentError("Failed authorization");
			}
		}

		const music = MusicKit.getInstance()!;
		this.music = music;

		music.repeatMode = MusicKit.PlayerRepeatMode.none;
		music.addEventListener("playbackTimeDidChange", () => {
			this.dispatchEvent(new MusicServiceEvent("timeupdate", this.music!.currentPlaybackTime));
		});
		music.addEventListener("mediaCanPlay", () => {
			this.dispatchEvent(new MusicServiceEvent("playing"));
		});

		// MusicKit attaches listeners to persist playback state on visibility state changes
		// Since we can pause/play/skip songs while in the background this isn't what we want, thus we make sure it is in the correct state
		music.addEventListener("playbackStateDidChange", async ({ state }) => {
			switch (state) {
				case MusicKit.PlaybackStates.ended:
					this.dispatchEvent(new MusicServiceEvent("ended"));
					break;
				case MusicKit.PlaybackStates.playing:
					if (!this.song) {
						await music.stop();
					}
					break;
			}
		});

		// NOTE: Required for Music Videos to work
		const dummyVideoContainer = document.createElement("div");
		music.videoContainerElement = dummyVideoContainer;
	}

	handleDeinitialization(): void {}

	async handlePlay(): Promise<void> {
		try {
			const { music, song } = this;
			if (!music || !song) return;

			await music.stop();

			if (song.data.musicVideo) {
				await music.setQueue({ musicVideo: song.id, startPlaying: true, startTime: 0 });
			} else {
				await music.setQueue({ song: song.id, startPlaying: true, startTime: 0 });
			}
		} catch (error) {
			console.log("err:", error);

			if (error instanceof Error) {
				// Someone skipped or stopped the song while it was still trying to play it, let it slide
				if (
					error.name === "AbortError" ||
					error.message.includes(
						"The play() method was called without a previous stop() or pause() call.",
					)
				) {
					return;
				}
			}

			throw error;
		}
	}

	async handleResume(): Promise<void> {
		await this.music?.play();
	}

	async handlePause(): Promise<void> {
		await this.music?.pause();
	}

	async handleStop(): Promise<void> {
		await this.music?.stop();
	}

	async handleSeekToTime(timeInSeconds: number): Promise<void> {
		await this.music?.seekToTime(timeInSeconds);
	}

	handleSetVolume(volume: number): void {
		if (!this.music) return;
		this.music.volume = volume;
	}
}
