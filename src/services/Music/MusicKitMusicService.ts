import { alertController } from "@ionic/vue";

import { LocalImage, useLocalImages } from "@/stores/local-images";
import { MusicKitSong, Playlist } from "@/stores/music-player";

import { MusicKitAuthorizationService } from "@/services/Authorization/MusicKitAuthorizationService";
import { MusicService, MusicServiceEvent, SilentError } from "@/services/Music/MusicService";

import { generateUUID } from "@/utils/crypto";
import { generateSongStyle } from "@/utils/songs";
import { Maybe } from "@/utils/types";

export async function musicKitSong(
	song: MusicKit.Songs | MusicKit.LibrarySongs,
): Promise<MusicKitSong> {
	const { id, attributes } = song;

	const artworkAttribute = attributes?.artwork;

	let artwork: Maybe<LocalImage>;
	if (artworkAttribute) {
		const localImages = useLocalImages();
		const artworkUrl = MusicKit.formatArtworkURL(artworkAttribute, 256, 256);
		try {
			const artworkBlob = await (await fetch(artworkUrl)).blob();
			await localImages.associateImage(id, artworkBlob);
			artwork = { id };
		} catch {
			// TODO: Remove this after Apple fixes artwork CORS issues
			artwork = { url: artworkUrl };
		}
	}

	const artists = attributes?.artistName ? [attributes?.artistName] : [];
	const genres = attributes?.genreNames ?? [];

	return {
		type: "musickit",

		id,
		artists,
		genres,

		title: attributes?.name,
		album: attributes?.albumName,
		duration: attributes?.durationInMillis && attributes?.durationInMillis / 1000,

		artwork,
		style: await generateSongStyle(artwork),

		data: {},
	};
}

export function musicKitSongIdType(id: string): "library" | "catalog" {
	if (!isNaN(Number(id))) {
		return "catalog";
	}
	return "library";
}

export class MusicKitMusicService extends MusicService<MusicKitSong> {
	logName = "MusicKitMusicService";
	logColor = "#cc80dd";
	type = "musickit" as const;
	available = true;

	music?: MusicKit.MusicKitInstance;
	authorization = new MusicKitAuthorizationService();

	constructor() {
		super();
	}

	async handleSearchHints(term: string): Promise<string[]> {
		if (!term) return [];

		const response = await this.music!.api.music<{ results: { terms: string[] } }>(
			"/v1/catalog/{{storefrontId}}/search/hints",
			{ term },
		);

		const { terms } = response.data.results;
		return terms;
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
		const title = playlist.attributes?.name ?? "Unknown title";
		const artworkAttribute = playlist.attributes?.artwork;

		let artwork: Maybe<LocalImage>;
		if (artworkAttribute) {
			const localImages = useLocalImages();
			const artworkUrl = MusicKit.formatArtworkURL(artworkAttribute, 256, 256);
			const artworkBlob = await (await fetch(artworkUrl)).blob();
			await localImages.associateImage(id, artworkBlob);
			artwork = { id };
		}

		const tracks = playlist.relationships?.tracks.data ?? [];
		const songs = await Promise.all(tracks.map(musicKitSong));

		return {
			id,
			importInfo: {
				id: musicKitId,
				type: "musickit",
				info: url.toString(),
			},
			title,
			artwork,
			songs,
		};
	}

	async handleSearchSongs(term: string, offset: number): Promise<MusicKitSong[]> {
		const response = await this.music!.api.music<
			MusicKit.SearchResponse,
			MusicKit.CatalogSearchQuery
		>("/v1/catalog/{{storefrontId}}/search", {
			term,
			types: ["songs", "music-videos"],
			limit: 25,
			offset,
		});

		const songs = response?.data?.results?.songs?.data;
		if (songs) {
			return await Promise.all(songs.map(musicKitSong));
		}
		return [];
	}

	handleGetSongFromSearchResult(searchResult: MusicKitSong): MusicKitSong {
		return searchResult;
	}

	async handleRefreshLibrarySongs(): Promise<void> {
		// TODO: Unimplemented
	}

	async handleGetSong(songId: string, cache = true): Promise<MusicKitSong> {
		if (cache) {
			const cachedSong = this.getCached(songId);
			if (cachedSong) return cachedSong;
		}

		const idType = musicKitSongIdType(songId);

		const response = await this.music!.api.music<
			MusicKit.SongsResponse | MusicKit.LibrarySongsResponse
		>(
			idType === "catalog"
				? `/v1/catalog/{{storefrontId}}/songs/${songId}`
				: `/v1/me/library/songs/${songId}`,
		);

		const [responseSong] = response.data.data;
		if (!responseSong) {
			throw new Error(`Failed to find a song with id: ${songId}`);
		}

		return this.cacheSong(await musicKitSong(responseSong));
	}

	async handleRefreshSong(song: MusicKitSong): Promise<MusicKitSong> {
		return await this.handleGetSong(song.id, false);
	}

	async handleLibrarySongs(offset: number): Promise<MusicKitSong[]> {
		const response = await this.music!.api.music<
			MusicKit.LibrarySongsResponse,
			MusicKit.LibrarySongsQuery
		>("/v1/me/library/songs", { limit: 25, offset });

		const songs = response.data.data
			.filter((song) => {
				// Filter out songs that cannot be played
				return !!song.attributes?.playParams;
			})
			.map((song) => this.getCached(song.id) ?? this.cacheSongPromise(musicKitSong(song)));

		return await Promise.all(songs);
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
			await music.setQueue({ song: song.id, startPlaying: true, startTime: 0 });
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
