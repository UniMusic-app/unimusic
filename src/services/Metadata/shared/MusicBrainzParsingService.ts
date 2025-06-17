import { LocalImage, useLocalImages } from "@/stores/local-images";
import { Maybe } from "@/utils/types";
import { Metadata, MetadataLookup, MetadataService } from "../MetadataService";
import { MusicBrainzResponse } from "./MusicBrainz";

const COVERARTARCHIVE_ENDPOINT = "https://coverartarchive.org/";
const APP_USER_AGENT = `${import.meta.env.VITE_APP_NAME}/${import.meta.env.VITE_APP_VERSION} (https://github.com/unimusic-app/unimusic)`;

export abstract class MusicBrainzParsingMetadataService extends MetadataService {
	async getArtwork(
		lookup: MetadataLookup,
		type: "release" | "release-group",
		id: string,
	): Promise<Maybe<LocalImage>> {
		this.log("Getting artwork for release", id);

		const url = new URL(`${type}/${id}/front`, COVERARTARCHIVE_ENDPOINT);

		// NOTE: for now Covert Art Archive does not have rate limits in place
		//       see: https://musicbrainz.org/doc/Cover_Art_Archive/API#Rate_limiting_rules
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

	async parseMusicBrainzMetadata(
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
			const artwork = await this.getArtwork(lookup, "release-group", release["release-group"].id);
			metadata.artwork = artwork;
		} catch (error) {
			this.log(`Failed to get artwork for`, lookup, metadata);
			console.error(error);
		}

		return metadata;
	}
}
