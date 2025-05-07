import BG, { buildURL, WebPoSignalOutput } from "bgutils-js";
import Innertube, { YTMusic, YTNodes } from "youtubei.js/web";

import {
	MusicService,
	MusicServiceEvent,
	SearchFilter,
	SearchResultItem,
} from "@/services/Music/MusicService";

import { LocalImage, useLocalImages } from "@/stores/local-images";
import { generateUUID } from "@/utils/crypto";
import { getPlatform, isElectron } from "@/utils/os";
import { Maybe } from "@/utils/types";
import type { Thumbnail } from "youtubei.js/dist/src/parser/misc";
import type { SearchContinuation } from "youtubei.js/dist/src/parser/ytmusic/Search";
import type { MusicSearchFilters } from "youtubei.js/dist/src/types";
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

const getCached = generateCacheMethod("youtube");

type YouTubeAlbum = Album<"youtube">;
type YoutubeAlbumPreview = AlbumPreview<"youtube">;
type YouTubeAlbumPreviewKey = AlbumPreviewKey<"youtube">;
type YouTubeAlbumKey = AlbumKey<"youtube">;
type YouTubeAlbumSong = AlbumSong<"youtube">;
type YouTubeArtist = Artist<"youtube">;
type YouTubeArtistPreview = ArtistPreview<"youtube">;
type _YouTubeArtistKey = ArtistKey<"youtube">;
type YouTubeSong = Song<"youtube">;
type YouTubeSongKey = SongKey<"youtube">;
type YouTubeSongPreview<HasId extends boolean = false> = SongPreview<"youtube", HasId>;
type YouTubeSongPreviewKey = SongPreviewKey<"youtube">;
type YoutubeDisplayableArtist = DisplayableArtist<"youtube">;

export async function extractArtwork(
	id: string,
	thumbnails?: Thumbnail[] | YTNodes.MusicThumbnail,
): Promise<Maybe<LocalImage>> {
	const thumbnailUrl = Array.isArray(thumbnails)
		? thumbnails?.[0]?.url
		: thumbnails?.contents?.[0]?.url;

	if (!thumbnailUrl) {
		return;
	}

	const localImages = useLocalImages();

	// NOTE: YouTube force rate-limits requests from Android WebView
	const fetch = getPlatform() === "android" ? window.capacitorFetch : window.fetch;

	const artworkBlob = await (await fetch(thumbnailUrl)).blob();
	await localImages.associateImage(id, artworkBlob, {
		maxWidth: 512,
		maxHeight: 512,
	});

	return { id };
}

export function youtubeDisplayableArtist(artist: {
	channel_id?: string;
	name: string;
}): YoutubeDisplayableArtist {
	const id = artist.channel_id;
	const title = artist.name;

	if (id) {
		const artistPreview: YouTubeArtistPreview = {
			id,
			type: "youtube",
			kind: "artistPreview",

			title,
		};
		cache(artistPreview);
		return getKey(artistPreview);
	}

	return { title };
}

export function youtubeArtistPreview(node: YTNodes.MusicResponsiveListItem): YouTubeArtistPreview {
	if (!node.id) {
		throw new Error("Cannot create ArtistPreview from a node without id");
	}
	if (node.item_type !== "artist" && node.item_type !== "library_artist") {
		throw new Error("youtubeArtistPreview can only be called on 'artist' and 'library_artist' nodes");
	}

	const artwork = node.thumbnails?.[0] && { url: node.thumbnails[0].url };

	return {
		id: node.id,
		type: "youtube",
		kind: "artistPreview",

		artwork,
		title: node.name ?? node.title,
	};
}

// TODO: Figure out why "artists" field is not populated on Android
export function youtubeSongPreview(
	node: YTNodes.MusicResponsiveListItem,
	nodeId: string,
	albumId?: string,
): YouTubeSongPreview<true>;
export function youtubeSongPreview(
	node: YTNodes.MusicResponsiveListItem,
	nodeId?: string,
	albumId?: string,
): YouTubeSongPreview<false>;
export function youtubeSongPreview(
	node: YTNodes.MusicResponsiveListItem,
	nodeId?: string,
	albumId?: string,
): YouTubeSongPreview {
	if (node.item_type !== "song" && node.item_type !== "video" && node.item_type !== "unknown") {
		throw new Error("youtubeSongPreview can only be called on 'song', 'video' and 'unknown' nodes");
	}

	const { id, title, album } = node;

	const artwork = node.thumbnails?.[0] && { url: node.thumbnails[0].url };

	const artists: YoutubeDisplayableArtist[] = [];
	if (node.artists?.length || node.authors?.length) {
		for (const artist of (node.artists ?? node.authors)!) {
			artists.push(youtubeDisplayableArtist(artist));
		}
	} else if (node?.author) {
		artists.push(youtubeDisplayableArtist(node.author));
	}

	const available = node.item_type !== "unknown";
	const explicit =
		node.badges?.some(
			(badge) => badge.is(YTNodes.MusicInlineBadge) && badge.icon_type === "MUSIC_EXPLICIT_BADGE",
		) ?? false;

	return {
		type: "youtube",
		kind: "songPreview",
		// Song might not have a visible ID if its not available
		id,

		title,
		artists,
		artwork,

		available,
		explicit,

		album: album?.name,

		genres: [],

		data: { albumId },
	};
}

export async function youtubeSong(
	trackInfo: YTMusic.TrackInfo,
	songPreview?: YouTubeSongPreview,
): Promise<YouTubeSong> {
	const { id, title, duration, thumbnail } = trackInfo.basic_info;

	if (!id) {
		throw new Error("Cannot generate YouTubeSong from trackInfo that doesn't have id");
	}

	const artwork = await extractArtwork(id, thumbnail);

	const available = songPreview?.available ?? trackInfo?.playability_status?.status === "OK";

	let album: Maybe<string>;
	let albumId = songPreview?.data?.albumId;
	let explicit = songPreview?.explicit ?? false;
	let artists = songPreview?.artists ?? [];
	if (trackInfo.tabs) {
		outer: for (const tab of trackInfo.tabs) {
			if (!tab.content?.is(YTNodes.MusicQueue)) continue;
			if (!tab.content?.content?.is(YTNodes.PlaylistPanel)) continue;

			for (const node of tab.content.content.contents) {
				if (!node.is(YTNodes.PlaylistPanelVideo) || !node.album?.id) continue;
				explicit ||= node.badges?.some(
					(badge) => badge.is(YTNodes.MusicInlineBadge) && badge.icon_type === "MUSIC_EXPLICIT_BADGE",
				);

				albumId = node.album.id;
				album = node.album.name;

				if (node.artists) {
					artists = node.artists?.map(youtubeDisplayableArtist);
				}

				break outer;
			}
		}
	} else {
		album = songPreview?.album;
		const browserMediaSession = trackInfo.player_overlays?.browser_media_session?.as(
			YTNodes.BrowserMediaSession,
		);
		if (browserMediaSession) {
			album = browserMediaSession.album.text;
		}
	}

	if (!artists.length && trackInfo.basic_info.author) {
		artists.push({ title: trackInfo.basic_info.author });
	}

	// TODO: Genres
	const genres = songPreview?.genres ?? [];

	return {
		type: "youtube",
		kind: "song",
		id,

		artists,
		genres,

		title,
		album,
		duration,

		available,
		explicit,

		artwork,

		data: { albumId },
	};
}

export function youtubeAlbumPreview(
	node: YTNodes.MusicTwoRowItem | YTNodes.MusicResponsiveListItem,
): YoutubeAlbumPreview {
	if (!node.id) {
		throw new Error("Cannot create AlbumPreview from a node without id");
	}

	const artists: YoutubeDisplayableArtist[] = [];
	if (node.artists?.length) {
		for (const artist of node.artists) {
			artists.push(youtubeDisplayableArtist(artist));
		}
	}

	let artwork: Maybe<LocalImage>;
	const thumbnails = "thumbnails" in node ? node.thumbnails : node.thumbnail;
	if (thumbnails?.[0]) {
		artwork = { url: thumbnails[0].url };
	}

	return {
		id: node.id!,
		type: "youtube",
		kind: "albumPreview",

		title: ("name" in node && node.name) || node.title?.toString(),

		artwork,
		artists,
	};
}

export async function youtubeAlbum(id: string, album: YTMusic.Album): Promise<YouTubeAlbum> {
	const title = album.header?.title.toString() ?? "Unknown title";

	const thumbnail = album.background?.as(YTNodes.MusicThumbnail);

	const artwork = await extractArtwork(id, thumbnail);

	const artists: YoutubeDisplayableArtist[] = [];
	const artistText = album.header?.as(YTNodes.MusicResponsiveHeader)?.strapline_text_one?.runs;
	if (artistText) {
		for (const run of artistText) {
			if (!("endpoint" in run)) continue;

			const id = run.endpoint?.payload?.browseId;
			const title = run.text;

			const cachedArtist = getCached("artist", id);
			if (cachedArtist) {
				artists.push(getKey(cachedArtist));
			} else if (id) {
				const artistPreview: YouTubeArtistPreview = {
					id,
					type: "youtube",
					kind: "artistPreview",

					title,
					artwork,
				};
				cache(artistPreview);
				artists.push(getKey(artistPreview));
			} else {
				artists.push({ title, artwork });
			}
		}
	}

	const songs: YouTubeAlbumSong[] = [];
	for (const node of album.contents) {
		const trackNumber = node.index !== undefined ? parseInt(node.index.toString()) : undefined;

		if (node.id) {
			const cached = getCached("song", node.id) ?? getCached("songPreview", node.id);
			let key;
			if (!cached) {
				const songPreview = cache(youtubeSongPreview(node, node.id, id));
				key = getKey(songPreview);
			} else {
				key = getKey(cached);
			}

			songs.push({
				trackNumber: isNaN(trackNumber!) ? undefined : trackNumber,
				song: key,
			});
		} else {
			const songPreview = youtubeSongPreview(node, node.id, id);

			songs.push({
				trackNumber: isNaN(trackNumber!) ? undefined : trackNumber,
				song: songPreview,
			});
		}
	}

	return {
		type: "youtube",
		kind: "album",
		id,
		title,
		artists,
		artwork,
		songs,
	};
}

const USER_AGENT =
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.1";
const GOOG_API_KEY = "AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw";
const REQUEST_KEY = "O43z0dpjhgX20SCx4KAo";

async function createWebPoMinter(): Promise<BG.WebPoMinter> {
	const fetch = isElectron() ? window.fetch : window.capacitorFetch;

	const headers = {
		"content-type": "application/json+protobuf",
		"user-agent": USER_AGENT,
		"x-goog-api-key": GOOG_API_KEY,
		"x-user-agent": "grpc-web-javascript/0.1",
	};

	const challengeResponse = await fetch(buildURL("Create", true), {
		method: "POST",
		headers,
		body: JSON.stringify([REQUEST_KEY]),
	});

	const challengeResponseData = await challengeResponse.json();

	const bgChallenge = BG.Challenge.parseChallengeData(challengeResponseData);

	if (!bgChallenge) {
		throw new Error("Could not get challenge");
	}

	const interpreterJavascript =
		bgChallenge.interpreterJavascript.privateDoNotAccessOrElseSafeScriptWrappedValue;

	// TODO: It would be a good idea to sandbox this, however I am unsure if that is possible
	// eslint-disable-next-line @typescript-eslint/no-implied-eval
	new Function(interpreterJavascript!)();

	const botguardClient = await BG.BotGuardClient.create({
		globalObj: globalThis,
		globalName: bgChallenge.globalName,
		program: bgChallenge.program,
	});

	const webPoSignalOutput: WebPoSignalOutput = [];
	const botguardResponse = await botguardClient.snapshot({ webPoSignalOutput });

	const integrityTokenResponse = await fetch(buildURL("GenerateIT", true), {
		method: "POST",
		headers,
		body: JSON.stringify([REQUEST_KEY, botguardResponse]),
	});

	const [integrityToken]: [string?] = await integrityTokenResponse.json();
	if (!integrityToken) {
		throw new Error(
			`Could not get integrity token. Interpreter Hash: ${bgChallenge.interpreterHash}`,
		);
	}

	const integrityTokenBasedMinter = await BG.WebPoMinter.create(
		{ integrityToken },
		webPoSignalOutput,
	);

	return integrityTokenBasedMinter;
}

export class YouTubeMusicService extends MusicService<"youtube"> {
	logName = "YouTubeMusicService";
	logColor = "#ff0000";
	type = "youtube" as const;
	available = getPlatform() !== "web";

	innertube?: Innertube;
	audio?: HTMLAudioElement;

	async handleInitialization(): Promise<void> {
		const audio = new Audio();
		document.body.appendChild(audio);
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

		// TODO: Proxy for web support
		const fetch = isElectron() ? ElectronMusicPlayer!.fetchShim : window.capacitorFetch;

		const tmp = await Innertube.create({
			generate_session_locally: false,
			retrieve_player: false,
			user_agent: USER_AGENT,
			fetch,
		});
		const { visitorData } = tmp.session.context.client;
		if (!visitorData) {
			throw new Error("Could not get visitor data");
		}

		const minter = await createWebPoMinter();
		const poToken = await minter.mintAsWebsafeString(visitorData);

		console.log("pot:", poToken);
		const innertube = await Innertube.create({
			po_token: poToken,
			visitor_data: visitorData,
			generate_session_locally: false,
			user_agent: USER_AGENT,
			// Some Innertube methods are hardcoded to use strings with english locale
			lang: "en-US",
			fetch,
		});

		this.innertube = innertube;
	}

	handleDeinitialization(): void {}

	async *handleSearchForItems(
		term: string,
		filter: SearchFilter,
	): AsyncGenerator<SearchResultItem<"youtube">, any, any> {
		const searchFilters: MusicSearchFilters = {};

		switch (filter) {
			case "top-results":
				searchFilters.type = "all";
				break;
			case "songs":
				searchFilters.type = "song";
				break;
			case "albums":
				searchFilters.type = "album";
				break;
			case "artists":
				searchFilters.type = "artist";
				break;
		}

		const results = await this.innertube!.music.search(term, searchFilters);
		let contents = results.contents
			?.filter((node) => node.is(YTNodes.MusicShelf))
			?.flatMap((shelf) => shelf.contents);
		let continuation: SearchContinuation | YTMusic.Search = results;

		while (contents) {
			for (const result of contents) {
				if (!result.id) continue;

				switch (result.item_type) {
					case "video":
					case "song":
						yield getCached("song", result.id) ??
							getCached("songPreview", result.id) ??
							cache(youtubeSongPreview(result, result.id));
						break;
					case "album":
						yield getCached("album", result.id) ??
							getCached("albumPreview", result.id) ??
							cache(youtubeAlbumPreview(result));
						break;
					case "artist":
					case "library_artist":
						// NOTE: We don't return cached artist here, since YouTube's Artist
						//		 has a wide thumbnail, which does not look pleasing
						yield getCached("artistPreview", result.id) ?? cache(youtubeArtistPreview(result));
						break;
				}
			}

			if (!continuation.has_continuation) {
				break;
			}

			continuation = await results.getContinuation();
			contents = continuation.contents?.contents?.filter((node) =>
				node.is(YTNodes.MusicResponsiveListItem),
			);
		}
	}

	async handleGetSongFromPreview(songPreview: YouTubeSongPreview<true>): Promise<YouTubeSong> {
		if (!this.innertube) {
			throw new Error(
				"Tried to call handleGetSongFromPreview() while YouTubeMusicService is not initialized",
			);
		}

		const cached = getCached("song", songPreview.id);
		if (cached) return cached;

		const info = await this.innertube.music.getInfo(songPreview.id);
		const song = cache(await youtubeSong(info, songPreview));
		return song;
	}

	async *handleGetSearchHints(term: string): AsyncGenerator<string> {
		const sections = await this.innertube!.music.getSearchSuggestions(term);
		for (const section of sections) {
			for (const suggestion of section.contents) {
				if (!suggestion.is(YTNodes.SearchSuggestion)) continue;
				yield suggestion.suggestion.toString();
			}
		}
	}

	async handleGetSongsAlbum(song: YouTubeSong, cache = true): Promise<Maybe<YouTubeAlbum>> {
		if (!song.data.albumId) {
			console.warn("Failed to retrieve album, song has no albumId:", song);
			return;
		}
		return await this.handleGetAlbum(song.data.albumId, cache);
	}

	async handleGetAlbum(id: string, useCache = true): Promise<Maybe<YouTubeAlbum>> {
		if (useCache) {
			const cachedAlbum = getCached("album", id);
			if (cachedAlbum) return cachedAlbum;
		}

		const album = await this.innertube!.music.getAlbum(id);
		return cache(await youtubeAlbum(id, album));
	}

	async handleGetAlbumFromPreview(albumPreview: YoutubeAlbumPreview): Promise<YouTubeAlbum> {
		const album = await this.getAlbum(albumPreview.id);
		if (!album) {
			throw new Error(`Failed to find album for albumPreview: ${albumPreview.id}`);
		}
		return album;
	}

	async handleGetArtist(id: string, useCache = true): Promise<Maybe<YouTubeArtist>> {
		if (useCache) {
			const cachedArtist = getCached("artist", id);
			if (cachedArtist) return cachedArtist;
		}

		const artist = await this.innertube!.music.getArtist(id);
		const title = artist.header?.title?.toString() ?? "Unknown title";

		let artwork: Maybe<LocalImage>;
		console.log(artist);
		if (artist.header?.is(YTNodes.MusicImmersiveHeader)) {
			console.log(artist.header.thumbnail?.contents);
			const thumbnail = artist.header.thumbnail?.contents?.[0];
			if (thumbnail) {
				const localImages = useLocalImages();
				const artworkBlob = await (await fetch(thumbnail.url)).blob();
				await localImages.associateImage(id, artworkBlob, {
					maxWidth: 512,
					maxHeight: 512,
				});
				artwork = { id };
			}
		}

		const songs: (YouTubeSongKey | YouTubeSongPreviewKey)[] = [];
		const albums: (YouTubeAlbumKey | YouTubeAlbumPreviewKey)[] = [];
		for (const section of artist.sections) {
			if (!section.is(YTNodes.MusicCarouselShelf) && !section.is(YTNodes.MusicShelf)) continue;

			for (const node of section.contents) {
				if (node.is(YTNodes.MusicResponsiveListItem) && node.id) {
					const songPreview = cache(youtubeSongPreview(node, node.id));
					songs.push(getKey(songPreview));
				} else if (node.is(YTNodes.MusicTwoRowItem) && node.item_type === "album" && node.id) {
					const albumPreview =
						getCached("album", node.id) ??
						getCached("albumPreview", node.id) ??
						cache(youtubeAlbumPreview(node));

					albums.push(getKey(albumPreview));
				}
			}
		}

		return cache<YouTubeArtist>({
			id,
			type: "youtube",
			kind: "artist",

			title,
			artwork,

			songs,
			albums,
		});
	}

	async *handleGetArtistsSongs(
		artist: YouTubeArtist | Filled<YouTubeArtist>,
	): AsyncGenerator<YouTubeSong | YouTubeSongPreview> {
		// continuation seems to be always null, so there's no reason to paginate
		const ytArtist = await this.innertube!.music.getArtist(artist.id);
		const songs = await ytArtist.getAllSongs();

		if (!songs?.contents) return;

		for (const song of songs?.contents) {
			if (!song.is(YTNodes.MusicResponsiveListItem)) continue;

			if (!song.id) {
				yield youtubeSongPreview(song, song.id);
				continue;
			}

			const songPreview =
				getCached("song", song.id) ??
				getCached("songPreview", song.id) ??
				cache(youtubeSongPreview(song, song.id));
			yield songPreview;
		}
	}

	async handleGetPlaylist(idOrUrl: URL): Promise<Maybe<Playlist>> {
		const youtubeId = idOrUrl.searchParams.get("list");
		if (!youtubeId) {
			return;
		}

		let playlist = await this.innertube!.music.getPlaylist(youtubeId);
		if (!playlist.contents) {
			return;
		}

		const id = generateUUID();
		const header = playlist.header?.as(YTNodes.MusicResponsiveHeader);
		const title = header?.title?.toString() ?? "Unknown title";
		const thumbnail = header?.thumbnail?.contents?.[0];

		let artwork: Maybe<LocalImage>;
		if (thumbnail) {
			const localImages = useLocalImages();
			const artworkBlob = await (await fetch(thumbnail.url)).blob();
			await localImages.associateImage(id, artworkBlob, {
				maxWidth: 512,
				maxHeight: 512,
			});
			artwork = { id };
		}

		const songs: SongKey[] = [];
		while (playlist?.contents) {
			for (const node of playlist.contents) {
				if (!node.is(YTNodes.MusicResponsiveListItem)) continue;
				if (node.id) {
					const songPreview = cache(youtubeSongPreview(node, node.id));
					const song = await this.getSongFromPreview(songPreview);
					songs.push(getKey(song));
				}
			}

			if (!playlist.has_continuation) break;
			playlist = await playlist.getContinuation();
		}

		return cache<Playlist>({
			id,
			type: "unimusic",
			kind: "playlist",
			title,
			artwork,
			songs,
		});
	}

	async handleGetSong(songId: string, useCache = true): Promise<YouTubeSong> {
		if (useCache) {
			const cachedSong = getCached("song", songId);
			if (cachedSong) return cachedSong;
		}

		const trackInfo = await this.innertube!.music.getInfo(songId);
		return cache(await youtubeSong(trackInfo));
	}

	async handleRefreshSong(song: YouTubeSong): Promise<YouTubeSong> {
		return await this.handleGetSong(song.id, false);
	}

	async handlePlay(): Promise<void> {
		const { innertube, song, audio } = this;

		// NOTE: WEB_EMBEDDED seems to not block audio only files
		const trackInfo = await innertube!.getInfo(song!.id, "WEB_EMBEDDED");

		const addAudioSource = (url: string, mimeType: string): void => {
			const source = document.createElement("source");
			source.src = url;
			source.type = mimeType;
			audio!.appendChild(source);
		};

		const streamingData = trackInfo.streaming_data;
		const formats = [streamingData?.adaptive_formats ?? [], streamingData?.formats ?? []];
		const potentialFormats = [];
		for (const potentialFormat of formats.flat()) {
			if (!potentialFormat.has_audio) continue;
			if (audio!.canPlayType(potentialFormat.mime_type) !== "probably") continue;

			potentialFormats.push(potentialFormat);
		}

		potentialFormats.sort((a, b) => {
			// NOTE: When minimizing the app Android WebView pauses the audio when it contains video!
			//       So we only use it as a fallback in case other formats fail.
			//		 And its also a good idea to just ship audio when possible anyways 🤷‍♂️
			const defaultComparison = Number(a.has_video) - Number(b.has_video) || b.bitrate - a.bitrate;

			// NOTE: iOS cannot properly play and data from adaptive formats.
			//       For now we prefer static formats, even if they also contain video or have worse audio quality
			//       For adaptive formats – we prefer anything thats not opus, as its support on iOS is catastrophic
			// TODO: Check if there is a way to get just audio...
			if (getPlatform() === "ios") {
				const aIsOpus = a.mime_type.includes("opus");
				const bIsOpus = b.mime_type.includes("opus");
				if (aIsOpus && !bIsOpus) {
					return 1;
				} else if (bIsOpus && !aIsOpus) {
					return -1;
				}

				return Number(a.average_bitrate ?? 0) - Number(b.average_bitrate ?? 0) || defaultComparison;
			}

			return defaultComparison;
		});

		console.log(potentialFormats);

		const urlToFormats: Record<string, unknown> = {};
		for (const format of potentialFormats) {
			const url = format.decipher(innertube!.session.player);
			addAudioSource(url, format.mime_type);
			urlToFormats[url] = format;
		}

		try {
			await audio!.play();
		} catch (error) {
			// Someone skipped or stopped the song while it was still trying to play it, let it slide
			if (error instanceof Error && error.name === "AbortError") {
				return;
			}
			throw error;
		}

		this.log("Playing format:", urlToFormats[audio!.currentSrc]);
	}

	async handleResume(): Promise<void> {
		await this.audio?.play();
	}

	handlePause(): void {
		this.audio?.pause();
	}

	handleStop(): void {
		if (this.audio) {
			this.audio.pause();
			this.audio.innerHTML = "";
			this.audio.srcObject = null;
			this.audio.load();
		}
	}

	handleSeekToTime(timeInSeconds: number): void {
		this.audio!.currentTime = timeInSeconds;
	}

	handleSetVolume(volume: number): void {
		this.audio!.volume = volume;
	}
}
