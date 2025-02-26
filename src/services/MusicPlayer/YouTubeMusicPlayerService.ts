import BG, { buildURL, WebPoSignalOutput } from "bgutils-js";
import Innertube, { YTMusic, YTNodes } from "youtubei.js/web";

import { MusicPlayerService, SongSearchResult } from "@/services/MusicPlayer/MusicPlayerService";
import type { YouTubeSong } from "@/stores/music-player";

import { getPlatform, isElectron } from "@/utils/os";
import { generateSongStyle } from "@/utils/songs";

export function youtubeSongSearchResult(
	node: YTNodes.MusicResponsiveListItem,
): SongSearchResult<YouTubeSong> {
	const artwork = node.thumbnails?.[0] && { url: createCapacitorProxyUrl(node.thumbnails[0].url) };

	return {
		type: "youtube",
		id: node.id!,
		title: node.title,
		album: node.album?.name,
		artist: node.artists?.[0]?.name,
		artwork,
	};
}

export async function youtubeSong(
	item: YTMusic.TrackInfo,
	searchResult?: SongSearchResult<YouTubeSong>,
): Promise<YouTubeSong> {
	const { id, title, author, duration, thumbnail, tags } = item.basic_info;

	if (!id) {
		throw new Error("Cannot generate YouTubeSong from item that doesn't have id");
	}

	const artwork = thumbnail?.[0] && { url: createCapacitorProxyUrl(thumbnail[0].url) };
	const album = searchResult?.album ?? tags?.at(-2);

	return {
		type: "youtube",

		id,
		title,
		artist: author,
		duration,
		album,
		// TODO: genre

		artwork,
		style: await generateSongStyle(artwork),

		data: {},
	};
}

const USER_AGENT =
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.1";
const GOOG_API_KEY = "AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw";
const REQUEST_KEY = "O43z0dpjhgX20SCx4KAo";

const SERVER_URL = "WEBVIEW_SERVER_URL" in window ? (window.WEBVIEW_SERVER_URL as string) : "";

/**
 * Create a proxied url which uses native layer to bypass CORS
 * @see https://github.com/ionic-team/capacitor/blob/90f95d1a829f3d87cb46af827b5bfaac319a9694/core/native-bridge.ts#L134
 */
function createCapacitorProxyUrl(url: string): string {
	if (!SERVER_URL) return url;
	const bridgeUrl = new URL(SERVER_URL);
	bridgeUrl.pathname = "/_capacitor_http_interceptor_";
	bridgeUrl.searchParams.append("u", url);
	return bridgeUrl.toString();
}

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

export class YouTubeMusicPlayerService extends MusicPlayerService<YouTubeSong> {
	logName = "YouTubeMusicPlayerService";
	logColor = "#ff0000";

	innertube?: Innertube;
	audio!: HTMLAudioElement;

	#innertubePromise = Promise.withResolvers<void>();
	#initializedInnertube?: Promise<void>;
	async handleInitialization(): Promise<void> {
		const audio = new Audio();
		audio.addEventListener("timeupdate", () => {
			this.store.time = audio.currentTime;
		});
		audio.addEventListener("playing", () => {
			this.store.addMusicSessionActionHandlers();
		});
		this.audio = audio;

		if (this.#initializedInnertube) {
			await this.#initializedInnertube;
			return;
		}
		this.#initializedInnertube = this.#innertubePromise.promise;

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
			fetch,
		});

		this.innertube = innertube;
		this.#innertubePromise.resolve();
	}

	handleDeinitialization(): void {
		this.audio.remove();
		this.audio = undefined!;
	}

	async handleSearchSongs(term: string, _offset: number): Promise<SongSearchResult<YouTubeSong>[]> {
		// TODO: Handle continuation
		const innertube = this.innertube!;

		const results = await innertube.music.search(term, { type: "song" });
		if (!results.contents) return [];

		const songs: SongSearchResult<YouTubeSong>[] = [];
		for (const result of results.contents) {
			if (!result.is(YTNodes.MusicShelf)) continue;

			for (const item of result.contents) {
				if (!item.id) continue;
				songs.push(youtubeSongSearchResult(item));
			}
		}
		return songs;
	}

	async handleGetSongFromSearchResult(
		searchResult: SongSearchResult<YouTubeSong>,
	): Promise<YouTubeSong> {
		if (!this.innertube) {
			throw new Error(
				"Tried to call handleGetSongFromSearchResult() while YouTubeMusicPlayerService is not initialized",
			);
		}

		const info = await this.innertube.music.getInfo(searchResult.id);
		const song = await youtubeSong(info, searchResult);
		return song;
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

	handleLibrarySongs(_offset: number): YouTubeSong[] {
		// TODO: Implement local version of it
		return [];
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
		const song = this.song!;

		// NOTE: WEB_EMBEDDED seems to not block audio only files
		const trackInfo = await innertube.getInfo(song.id, "WEB_EMBEDDED");

		const { audio } = this;

		const addAudioSource = (url: string, mimeType: string): void => {
			const source = document.createElement("source");
			source.src = url;
			source.type = mimeType;
			audio.appendChild(source);
		};

		const streamingData = trackInfo.streaming_data;
		const formats = [streamingData?.adaptive_formats ?? [], streamingData?.formats ?? []];
		const potentialFormats = [];
		for (const potentialFormat of formats.flat()) {
			if (!potentialFormat.has_audio) continue;
			if (audio.canPlayType(potentialFormat.mime_type) !== "probably") continue;

			potentialFormats.push(potentialFormat);
		}

		potentialFormats.sort((a, b) => {
			// NOTE: Android WebView pauses the audio when it contains video!
			//       So we only use it as a fallback in case other formats fail
			//		 And its also a good idea to just ship audio when possible anyways 🤷‍♂️
			const defaultComparison = Number(a.has_video) - Number(b.has_video) || b.bitrate - a.bitrate;

			// NOTE: iOS cannot properly play and data from adaptive opus format
			//       So we prefer other formats (even with video) over it
			if (getPlatform() === "ios") {
				const aIsOpus = a.mime_type.includes("opus");
				const bIsOpus = b.mime_type.includes("opus");
				if (aIsOpus && !bIsOpus) {
					return 1;
				} else if (bIsOpus && !aIsOpus) {
					return -1;
				}
			}

			return defaultComparison;
		});

		console.log(potentialFormats);

		const urlToFormats: Record<string, unknown> = {};
		for (const format of potentialFormats) {
			const url = format.decipher(this.innertube!.session.player);
			addAudioSource(url, format.mime_type);
			urlToFormats[url] = format;
		}

		await audio.play();
		this.log("Playing format:", urlToFormats[audio.currentSrc]);
	}

	async handleResume(): Promise<void> {
		await this.audio.play();
	}

	handlePause(): void {
		this.audio.pause();
	}

	handleStop(): void {
		this.audio.pause();
	}

	handleSeekToTime(timeInSeconds: number): void {
		this.audio.currentTime = timeInSeconds;
	}

	handleSetVolume(volume: number): void {
		this.audio.volume = volume;
	}
}
