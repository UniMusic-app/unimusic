import { LocalImage, useLocalImages } from "@/stores/local-images";
import { getFileStream } from "@/utils/path";
import { PromiseQueue } from "@/utils/promise-queue";
import { RateLimiter } from "@/utils/rate-limiter";
import { sleep } from "@/utils/time";
import { Maybe } from "@/utils/types";
import { useIDBKeyvalAsync } from "@/utils/vue";
import { processAudioFile } from "@unimusic/chromaprint";
import { Metadata, MetadataLookup, MetadataService } from "./MetadataService";
import { AcoustIDResponse } from "./types/AcoustID";
import { MusicBrainzResponse } from "./types/MusicBrainz";

const MUSICBRAINZ_ENDPOINT = "https://musicbrainz.org/ws/2/";
const ACOUSTID_ENDPOINT = "https://api.acoustid.org/v2/lookup";
const COVERARTARCHIVE_ENDPOINT = "https://coverartarchive.org/";
const APP_USER_AGENT = `UniMusic/${import.meta.env.VITE_APP_NAME} (https://github.com/unimusic-app/unimusic)`;

const cachedMetadata = await useIDBKeyvalAsync<Record<string, Metadata>>(
	"musicBrainzMetadataCache",
	{},
);

const fingerprintQueue = new PromiseQueue<string>();

const rateLimiter = new RateLimiter({
	// 1 request per second
	// see: https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting#Source_IP_address
	"musicbrainz.org": 1000,

	// 3 requests per second
	// see: https://acoustid.org/webservice
	"api.acoustid.org": 1000 / 3,

	// NOTE: for now Covert Art Archive does not have rate limits in place
	//       see: https://musicbrainz.org/doc/Cover_Art_Archive/API#Rate_limiting_rules
});

export class MusicBrainzLyricsService extends MetadataService {
	logName = "MusicBrainzMetadataService";
	logColor = "#EB753B";

	async #getArtwork(
		lookup: MetadataLookup,
		type: "release" | "release-group",
		id: string,
	): Promise<Maybe<LocalImage>> {
		this.log("Getting artwork for release", id);

		const url = new URL(`${type}/${id}/front`, COVERARTARCHIVE_ENDPOINT);

		const response = await fetch(url, { headers: { "user-agent": APP_USER_AGENT } });
		if (!response.ok) {
			throw new Error(`Failed to get artwork for ${type}: ${id}`);
		}

		const image = await response.blob();

		const localImages = useLocalImages();
		await localImages.associateImage(lookup.id, image);

		this.log(`Got artwork for ${type}`, id);

		return { id: lookup.id };
	}

	async #getMetadataFromFingerprint(
		lookup: MetadataLookup,
		fingerprint: string,
	): Promise<Maybe<Metadata>> {
		this.log("Getting metadata from fingerprint");
		const url = new URL(ACOUSTID_ENDPOINT);

		url.searchParams.set("client", import.meta.env.VITE_ACOUSTID_TOKEN);
		url.searchParams.set("duration", String(Math.round(lookup.duration!)));
		url.searchParams.set("meta", "compress recordings releases releasegroups tracks");
		url.searchParams.set("fingerprint", fingerprint);

		const response = await rateLimiter.fetch(url, { headers: { "user-agent": APP_USER_AGENT } });
		if (!response.ok) {
			throw new Error("Failed to lookup metadata by fingerprint");
		}

		const json: AcoustIDResponse = await response.json();

		const [result] = json.results;
		if (!result) return;

		// Only AcoustID trackId present without metadata
		if (!result?.recordings) {
			this.log("AcoustID did not return any recordings (metadata missing)");
			return;
		}

		const [recording] = result.recordings;
		if (!recording) return;

		// Only MusicBrainz id present, try to fetch it
		if (!recording.releasegroups) {
			this.log("No release groups present, fetching metadata directly from MusicBrainz");

			const url = new URL(`recording/${recording.id}`, MUSICBRAINZ_ENDPOINT);
			url.searchParams.set("fmt", "json");

			const response = await rateLimiter.fetch(url, { headers: { "user-agent": APP_USER_AGENT } });
			const json: MusicBrainzResponse = await response.json();
			const metadata = await this.#parseMusicBrainzMetadata(lookup, json);
			return metadata;
		}

		const [releaseGroup] = recording.releasegroups;
		if (!releaseGroup) return;

		this.log("Got metadata from fingerprint");

		const metadata: Metadata = {};

		metadata.title = recording.title;
		metadata.album = recording.releasegroups.find((group) => group.type === "Album")?.title;
		metadata.artists = recording.artists.map((artist) => ({ id: artist.id, title: artist.name }));

		try {
			const artwork = await this.#getArtwork(lookup, "release-group", releaseGroup.id);
			metadata.artwork = artwork;
		} catch (error) {
			this.log(`Failed to get artwork for`, lookup, metadata);
			console.error(error);
		}

		cachedMetadata.value[lookup.id] = metadata;
		cachedMetadata.value[fingerprint] = metadata;

		return metadata;
	}

	async #parseMusicBrainzMetadata(
		lookup: MetadataLookup,
		response: MusicBrainzResponse,
	): Promise<Maybe<Metadata>> {
		const metadata: Metadata = {};

		if (!response.recordings) {
			this.log("MusicBrainz does not have recordings information");
			return;
		}

		const [recording] = response.recordings;
		if (!recording) return;

		const [release] = recording.releases;
		if (!release) return;

		this.log("Got metadata from lookup", release);

		const releaseGroup = release["release-group"];

		metadata.title = recording.title;
		if (releaseGroup["primary-type"] === "Album") {
			metadata.album = releaseGroup.title;
		}
		metadata.artists =
			release["artist-credit"]?.map((artist) => ({
				id: artist.id,
				title: artist.name,
			})) ?? [];

		try {
			const artwork = await this.#getArtwork(lookup, "release-group", release["release-group"].id);
			metadata.artwork = artwork;
		} catch (error) {
			this.log(`Failed to get artwork for`, lookup, metadata);
			console.error(error);
		}

		cachedMetadata.value[lookup.id] = metadata;

		return metadata;
	}

	async #getMetadataFromLookup(lookup: MetadataLookup): Promise<Maybe<Metadata>> {
		this.log("Getting metadata from lookup");

		const url = new URL("recording", MUSICBRAINZ_ENDPOINT);

		let query = "";
		if (lookup.title) {
			query += `recording:${lookup.title}`;
		}
		if (lookup.album) {
			query += ` AND album:${lookup.album}`;
		}
		if (lookup.artists?.[0]) {
			query += ` AND artist:${lookup.artists[0]}`;
		}
		if (lookup.duration) {
			// MusicBrainz measures duration in ms
			const duration = lookup.duration * 1000;
			const leeway = 2000;
			query += ` AND dur:[${duration - leeway} TO ${duration + leeway}]`;
		}

		url.searchParams.set("query", query);
		url.searchParams.set("fmt", "json");

		const response = await rateLimiter.fetch(url, { headers: { "user-agent": APP_USER_AGENT } });
		if (!response.ok) {
			throw new Error("Failed to lookup metadata");
		}

		const json: MusicBrainzResponse = await response.json();
		const metadata = await this.#parseMusicBrainzMetadata(lookup, json);
		return metadata;
	}

	async handleGetMetadata(lookup: MetadataLookup): Promise<Maybe<Metadata>> {
		const cached = cachedMetadata.value[lookup.id];
		if (cached) {
			this.log("Metadata cache hit for", lookup, cached);
			return cached;
		}

		try {
			if (lookup.filePath) {
				const fileStream = await getFileStream(lookup.filePath);
				const fileBuffer = await new Response(fileStream).arrayBuffer();
				const fingerprint = await fingerprintQueue.push(async () => {
					const [fingerprint] = await Array.fromAsync(processAudioFile(fileBuffer));
					// This delay is necessary, because for whatever reason chrome can just crash
					// If files are decoded in quick succession
					await sleep(1000);
					return fingerprint!;
				});

				this.log("Fingerprint:", fingerprint?.slice(0, 10) + "...");

				if (!fingerprint) {
					this.log("Failed to read any fingerprint from a file", lookup);
				} else {
					const cached = cachedMetadata.value[fingerprint];
					if (cached) {
						this.log("Metadata cache hit from fingerprint for", lookup);
						return cached;
					}

					const metadata = await this.#getMetadataFromFingerprint(lookup, fingerprint);
					if (metadata) return metadata;
				}
			}
		} catch (error) {
			this.log("Failed to retrieve metadata using fingerprint");
			console.error(error);
		}

		try {
			const metadata = await this.#getMetadataFromLookup(lookup);
			return metadata;
		} catch (error) {
			this.log("Failed to retrieve metadata from lookup", lookup);
			console.error(error);
		}

		this.log("Found no metadata for", lookup);
	}
}
