import { Metadata, MetadataLookup } from "./MetadataService";

import { AcoustIDResponse } from "./shared/AcoustID";
import { MusicBrainzResponse } from "./shared/MusicBrainz";
import { MusicBrainzParsingMetadataService } from "./shared/MusicBrainzParsingService";

import { getPlatform } from "@/utils/os";
import { getFileStream } from "@/utils/path";
import { PromiseQueue } from "@/utils/promise-queue";
import { RateLimiter } from "@/utils/rate-limiter";
import { sleep } from "@/utils/time";
import { Maybe } from "@/utils/types";
import { useIDBKeyvalAsync } from "@/utils/vue";

let processAudioFile: typeof import("@unimusic/chromaprint").processAudioFile;
if (getPlatform() !== "web") {
	({ processAudioFile } = await import("@unimusic/chromaprint"));
}

const MUSICBRAINZ_ENDPOINT = "https://musicbrainz.org/ws/2/";
const ACOUSTID_ENDPOINT = "https://api.acoustid.org/v2/lookup";
const APP_USER_AGENT = `${import.meta.env.VITE_APP_NAME}/${import.meta.env.VITE_APP_VERSION} (https://github.com/unimusic-app/unimusic)`;

const cachedMetadata = await useIDBKeyvalAsync<Record<string, Metadata>>(
	"acoustIdMetadataCache",
	{},
);

const fingerprintQueue = new PromiseQueue<string>();

const rateLimiter = new RateLimiter({
	// 3 requests per second
	// see: https://acoustid.org/webservice
	"api.acoustid.org": 1000 / 3,

	// 1 request per second
	// see: https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting#Source_IP_address
	"musicbrainz.org": 1000,
});

export class AcoustIDMetadataService extends MusicBrainzParsingMetadataService {
	name = "AcoustID";
	description = "Uses AcoustID fingerprinting for metadata retrieval, it can be energy taxing.";
	logName = "AcoustIDMetadataService";
	logColor = "#9C1F14";
	available = getPlatform() !== "web";

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
						const metadata = await this.parseMusicBrainzMetadata(lookup, json);
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
						const artwork = await this.getArtwork(lookup, "release-group", releaseGroup.id);
						metadata.artwork = artwork;
					} catch (error) {
						this.log(`Failed to get artwork for`, lookup, metadata);
						console.error(error);
					}

					cachedMetadata.value[lookup.id] = metadata;
					cachedMetadata.value[fingerprint] = metadata;

					return metadata;
				}
			}
		} catch (error) {
			this.log("Failed to retrieve metadata using fingerprint");
			console.error(error);
		}
	}
}
