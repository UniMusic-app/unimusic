import { LocalImage, useLocalImages } from "@/stores/local-images";
import { getPlatform } from "@/utils/os";
import { Maybe } from "@/utils/types";
import { Metadata, MetadataLookup, MetadataService } from "../MetadataService";
import { MusicBrainzResponse } from "./MusicBrainz";

const COVERARTARCHIVE_ENDPOINT = "https://coverartarchive.org/";

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
		const response = await fetch(
			url,
			// FIXME: on iOS setting user-agent on fetch fails, and capacitorFetch fails to properly return a blob
			getPlatform() === "ios" ? undefined : { headers: { "user-agent": APP_USER_AGENT } },
		);
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

		const metadata: Metadata = {
			musicbrainzId: recording.id,
			title: recording.title,
		};

		if (releaseGroup["primary-type"] === "Album") {
			metadata.album = releaseGroup.title;
		}

		if (release["artist-credit"]?.length) {
			metadata.artists = [];
			for (const { artist } of release["artist-credit"]) {
				const artistPreview = {
					id: artist.id,
					title: artist.name,
				};
				metadata.artists.push(artistPreview);
			}
		}

		if (release.media.length) {
			const media = release.media[0]!;

			metadata.discNumber = media.position;
			if (media.track[0]?.number) {
				metadata.trackNumber = Number(media.track[0].number);
			}
		}

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
