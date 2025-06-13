import { DisplayableArtist } from "@/services/Music/objects";
import { Service } from "@/services/Service";
import { LocalImage } from "@/stores/local-images";
import { Maybe } from "@/utils/types";

export interface Metadata {
	isrc?: string[];

	title?: string;
	album?: string;
	artists?: DisplayableArtist[];
	genres?: string[];

	duration?: number;
	artwork?: LocalImage;

	discNumber?: number;
	trackNumber?: number;
}

export interface MetadataLookup {
	id: string;

	title?: string;
	album?: string;
	artists?: string[];
	duration?: number;
	isrc?: string;

	fileStream?: ReadableStream<Uint8Array>;
	fileName?: string;
}

export abstract class MetadataService extends Service {
	handleGetMetadata?(lookup: MetadataLookup): Maybe<Metadata> | Promise<Maybe<Metadata>>;
	async getMetadata(lookup: MetadataLookup): Promise<Maybe<Metadata>> {
		this.log("getMetadataFromSong");

		if (!this.handleGetMetadata) {
			throw new Error("This service does not support getMetadataFromString");
		}

		const metadata = await this.handleGetMetadata(lookup);
		return metadata;
	}
}
