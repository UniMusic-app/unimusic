export interface CoverArtArchiveImage {
	id: number;
	comment: string;

	approved: boolean;

	back: boolean;
	font: boolean;

	edit: number;

	image: string;
	thumbnails: {
		250: string;
		500: string;
		large: string;
		small: string;
	};
	types: string[];
}

export interface CoverArtArchiveResponse {
	images: CoverArtArchiveImage[];
	release: string;
}
