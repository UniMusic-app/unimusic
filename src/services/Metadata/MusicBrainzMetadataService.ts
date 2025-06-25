import { getPlatform } from "@/utils/os";
import { RateLimiter } from "@/utils/rate-limiter";
import { Maybe } from "@/utils/types";
import { useIDBKeyvalAsync } from "@/utils/vue";
import { Metadata, MetadataLookup } from "./MetadataService";
import { MusicBrainzResponse } from "./shared/MusicBrainz";
import { MusicBrainzParsingMetadataService } from "./shared/MusicBrainzParsingService";

const MUSICBRAINZ_ENDPOINT = "https://musicbrainz.org/ws/2/";
const APP_USER_AGENT = `${import.meta.env.VITE_APP_NAME}/${import.meta.env.VITE_APP_VERSION} (https://github.com/unimusic-app/unimusic)`;

const cachedMetadata = await useIDBKeyvalAsync<Record<string, Metadata>>(
	"musicBrainzMetadataCache",
	{},
);

const rateLimiter = new RateLimiter({
	// 1 request per second
	// see: https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting#Source_IP_address
	"musicbrainz.org": 1000,
});

export class MusicBrainzMetadataService extends MusicBrainzParsingMetadataService {
	name = "MusicBrainz";
	description = "Queries MusicBrainz with song information for potential metadata match";
	logName = "MusicBrainzMetadataService";
	logColor = "#EB753B";
	available = getPlatform() !== "web";

	async handleGetMetadata(lookup: MetadataLookup): Promise<Maybe<Metadata>> {
		const cached = cachedMetadata.value[lookup.id];
		if (cached) {
			this.log("Metadata cache hit for", lookup, cached);
			return cached;
		}

		try {
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
			const metadata = await this.parseMusicBrainzMetadata(lookup, json);
			if (metadata) cachedMetadata.value[lookup.id] = metadata;
			return metadata;
		} catch (error) {
			this.log("Failed to retrieve metadata from lookup", lookup);
			console.error(error);
		}
	}
}
