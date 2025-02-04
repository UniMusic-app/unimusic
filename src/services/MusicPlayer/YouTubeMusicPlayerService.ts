import Innertube, { UniversalCache, YTMusic, YTNodes } from "youtubei.js/web";
import BG, { BgConfig } from "bgutils-js";
import dashjs, { MediaPlayerClass } from "dashjs";

import type { SongImage, YouTubeSong } from "@/stores/music-player";
import { generateSongStyle } from "@/utils/songs";
import { MusicPlayerService } from "@/services/MusicPlayer/MusicPlayerService";

export async function youtubeSong(item: YTMusic.TrackInfo): Promise<YouTubeSong> {
	const { id, title, author, duration, thumbnail, tags } = item.basic_info;

	if (!id) {
		throw new Error("Cannot generate YouTubeSong from item that doesn't have id");
	}

	const artwork = thumbnail?.[0] && { url: thumbnail[0].url };
	// TODO: This is most likely not accurate for all songs
	const album = tags?.at(-2);

	return {
		type: "youtube",

		id,
		title,
		artist: author,
		duration,
		album,
		// TODO: genre, album

		artwork,
		style: await generateSongStyle(artwork),

		data: {},
	};
}

export class YouTubeMusicService extends MusicPlayerService<YouTubeSong> {
	logName = "YouTubeMusicService";
	logColor = "#ff0000";

	innertube?: Innertube;
	mediaPlayer?: MediaPlayerClass;

	async handleInitialization(): Promise<void> {
		// youtube.js seems to be destructurizing fetch somewhere, which causes
		// "Illegal Invocation error", so we just provide our own
		// TODO: Proxy for web support
		// TODO: Native "fetch" functions on iOS and Android
		const fetch = window.fetch.bind(window);

		// #region Generate PoToken to allow playback of whole tracks
		// TODO: This probably should get sandboxed in an iframe, since
		let innertube = await Innertube.create({ retrieve_player: false });
		const requestKey = "O43z0dpjhgX20SCx4KAo";

		const visitorData = innertube.session.context.client.visitorData;
		if (!visitorData) {
			throw new Error("Could not get visitor data");
		}

		const bgConfig: BgConfig = {
			fetch: (input: string | URL | globalThis.Request, init?: RequestInit) => fetch(input, init),
			globalObj: globalThis,
			identifier: visitorData,
			requestKey,
		};

		const bgChallenge = await BG.Challenge.create(bgConfig);
		if (!bgChallenge) {
			throw new Error("Could not get challenge");
		}

		const interpreterJavascript =
			bgChallenge.interpreterJavascript.privateDoNotAccessOrElseSafeScriptWrappedValue;

		if (interpreterJavascript) {
			new Function(interpreterJavascript)();
		} else {
			throw new Error("Could not load VM");
		}

		const poTokenResult = await BG.PoToken.generate({
			program: bgChallenge.program,
			globalName: bgChallenge.globalName,
			bgConfig,
		});
		// #endregion

		innertube = await Innertube.create({
			po_token: poTokenResult.poToken,
			visitor_data: visitorData,
			cache: new UniversalCache(true),
			generate_session_locally: true,
			fetch,
		});

		this.innertube = innertube;

		const audio = new Audio();
		audio.addEventListener("timeupdate", () => {
			this.store.time = audio.currentTime;
		});
		audio.addEventListener("playing", () => {
			this.store.addMusicSessionActionHandlers();
		});

		const mediaPlayer = dashjs.MediaPlayer().create();
		mediaPlayer.setAutoPlay(false);
		mediaPlayer.initialize(audio);
		this.mediaPlayer = mediaPlayer;
	}

	async handleDeinitialization(): Promise<void> {
		this.mediaPlayer?.getVideoElement()?.remove();
		this.mediaPlayer!.destroy();
	}

	async handleSearchSongs(term: string, offset: number): Promise<YouTubeSong[]> {
		// TODO: Handle continuation
		const innertube = this.innertube!;

		const results = await innertube.music.search(term, { type: "song" });
		if (!results.contents) return [];

		const songs: Promise<YouTubeSong>[] = [];
		for (const result of results.contents) {
			if (!result.is(YTNodes.MusicShelf)) continue;

			for (const item of result.contents) {
				if (!item.id) continue;
				const song = innertube.music.getInfo(item.id).then(youtubeSong);
				songs.push(song);
			}
		}
		return await Promise.all(songs);
	}

	async handleSearchHints(term: string): Promise<string[]> {
		const sections = await this.innertube!.music.getSearchSuggestions(term);
		const hints: string[] = [];
		for (const section of sections) {
			for (const suggestion of section.contents) {
				if (suggestion.is(YTNodes.SearchSuggestion)) {
					hints.push(suggestion.suggestion.toString());
				}
			}
		}
		return hints;
	}

	async handleLibrarySongs(offset: number): Promise<YouTubeSong[]> {
		// TODO: Handle continuation
		// TODO: Requires authorization
		const innertube = this.innertube!;

		const library = await innertube.music.getLibrary();
		if (!library.contents) return [];

		const songs: Promise<YouTubeSong>[] = [];
		for (const result of library.contents) {
			if (!result.is(YTNodes.MusicShelf)) continue;

			for (const item of result.contents) {
				if (!item.id) continue;
				const song = innertube.music.getInfo(item.id).then(youtubeSong);
				songs.push(song);
			}
		}
		return await Promise.all(songs);
	}

	async handleRefreshLibrarySongs(): Promise<void> {
		// TODO: Unimplemented
	}

	async handleRefreshSong(song: YouTubeSong): Promise<YouTubeSong> {
		const trackInfo = await this.innertube!.music.getInfo(song.id);
		return youtubeSong(trackInfo);
	}

	async handlePlay(): Promise<void> {
		const innertube = this.innertube!;

		const trackInfo = await innertube.getInfo(this.song!.id);
		const manifest = await trackInfo!.toDash();
		const uri = "data:application/dash+xml;charset=utf-8;base64," + btoa(manifest);

		const mediaPlayer = this.mediaPlayer!;
		mediaPlayer.attachSource(uri);
		mediaPlayer.play();
	}

	async handleResume(): Promise<void> {
		this.mediaPlayer!.play();
	}

	async handlePause(): Promise<void> {
		this.mediaPlayer!.pause();
	}

	async handleStop(): Promise<void> {}

	handleSeekToTime(timeInSeconds: number): void | Promise<void> {
		this.mediaPlayer!.seek(timeInSeconds);
	}

	handleSetVolume(volume: number): void | Promise<void> {
		this.mediaPlayer!.setVolume(volume);
	}
}
