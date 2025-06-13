import { LocalImage, useLocalImages } from "@/stores/local-images";
import { Maybe } from "@/utils/types";
import { processAudioFile } from "@unimusic/chromaprint";
import { Metadata, MetadataLookup, MetadataService } from "./MetadataService";
import { AcoustIDResponse } from "./types/AcoustID";
import { MusicBrainzResponse } from "./types/MusicBrainz";

const MUSICBRAINZ_ENDPOINT = "https://musicbrainz.org/ws/2/";
const ACOUSTID_ENDPOINT = "https://api.acoustid.org/v2/lookup";
const COVERTARTARCHIVE_ENDPOINT = "https://coverartarchive.org/";
const APP_USER_AGENT = `UniMusic/${import.meta.env.VITE_APP_NAME} (https://github.com/unimusic-app/unimusic)`;

// TODO: Cache fetched metadata
// TODO: Put proper ratelimits in place
export class MusicBrainzLyricsService extends MetadataService {
	logName = "MusicBrainzMetadataService";
	logColor = "#EB753B";

	async #getArtwork(
		lookup: MetadataLookup,
		type: "release" | "release-group",
		id: string,
	): Promise<Maybe<LocalImage>> {
		this.log("Getting artwork for release", id);

		const url = new URL(`${type}/${id}/front`, COVERTARTARCHIVE_ENDPOINT);

		const response = await fetch(url);
		if (!response.ok) {
			throw new Error(`Failed to get artwork for ${type}: ${id}`);
		}

		const image = await response.blob();

		const localImages = useLocalImages();
		await localImages.associateImage(lookup.id, image);

		this.log("Got artwork for ${type}", id);
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

		const response = await fetch(url, { headers: { "user-agent": APP_USER_AGENT } });
		if (!response.ok) {
			throw new Error("Failed to lookup metadata by fingerprint");
		}

		const json: AcoustIDResponse = await response.json();

		const [result] = json.results;
		if (!result) return;

		const [recording] = result.recordings;
		if (!recording) return;

		const [releaseGroup] = recording.releasegroups;
		if (!releaseGroup) return;

		const [release] = releaseGroup.releases;
		if (!release) return;

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

		const response = await fetch(url, { headers: { "user-agent": APP_USER_AGENT } });
		if (!response.ok) {
			throw new Error("Failed to lookup metadata");
		}

		const json: MusicBrainzResponse = await response.json();

		const metadata: Metadata = {};

		const [recording] = json.recordings;
		if (!recording) return;

		const [release] = recording.releases;
		if (!release) return;

		this.log("Got metadata from lookup");

		const releaseGroup = release["release-group"];

		metadata.title = recording.title;
		if (releaseGroup["primary-type"] === "Album") {
			metadata.album = releaseGroup.title;
		}
		metadata.artists = release["artist-credit"].map((artist) => ({
			id: artist.id,
			title: artist.name,
		}));

		try {
			const artwork = await this.#getArtwork(lookup, "release-group", release["release-group"].id);
			metadata.artwork = artwork;
		} catch (error) {
			this.log(`Failed to get artwork for`, lookup, metadata);
			console.error(error);
		}

		return metadata;
	}

	async handleGetMetadata(lookup: MetadataLookup): Promise<Maybe<Metadata>> {
		try {
			console.time("Fingerprint");
			const fileBuffer = await new Response(lookup.fileStream).arrayBuffer();
			const [fingerprint] = await Array.fromAsync(processAudioFile(fileBuffer));
			this.log("Fingerprint:", fingerprint?.slice(0, 10) + "...");
			console.timeEnd("Fingerprint");

			if (!fingerprint) {
				this.log("Failed to read any fingerprint from a file", lookup);
			} else {
				const metadata = await this.#getMetadataFromFingerprint(lookup, fingerprint);
				if (metadata) return metadata;
			}
		} catch (error) {
			this.log("Failed to retrieve metadata using fingerprint");
			console.error(error);
		}

		try {
			// Try to guess song title and artists from file name if they are missing
			if (lookup.fileName) {
				// TODO: Add more patterns
				const [artists, songTitle] = lookup.fileName.split(/\s+?-\s+?/);
				if (!lookup.title) lookup.title = songTitle?.replace(/\(.+/, "").trim();
				if (!lookup.artists) lookup.artists = artists?.split(/\s*(?:&|,)\s+/);

				this.log("Adjusted lookup:", lookup);
			}

			const metadata = await this.#getMetadataFromLookup(lookup);
			return metadata;
		} catch (error) {
			this.log("Failed to retrieve metadata from lookup", lookup);
			console.error(error);
		}

		this.log("Found no metadata for", lookup);
	}
}
