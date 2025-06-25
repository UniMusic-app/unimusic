export interface MusicBrainzArtist {
	id: string;
	name: string;
}

export interface MusicBrainzArtistCredit {
	name: string;
	artist: MusicBrainzArtist;
}

export interface MusicBrainzReleaseGroup {
	id: string;
	title: string;
	"primary-type": "Album" | (string & {});
	date: string;
	country: string;
}

export interface MusicBrainzTrack {
	id: string;
	number: `${number}`;
	title: string;
	lemgth: string;
}

export interface MusicBrainzMedia {
	id: string;
	format: "CD" | (string & {});
	position: number;
	"track-count": number;
	"track-offset": number;
	track: MusicBrainzTrack[];
}

export interface MusicBrainzRelease {
	id: string;
	"status-id": string;
	"artist-credit-id": string;

	count: number;
	title: string;
	status: "Official" | "Bootleg" | (string & {});

	"artist-credit": MusicBrainzArtistCredit[];
	"release-group": MusicBrainzReleaseGroup;

	"track-count": number;
	media: MusicBrainzMedia[];
}

export interface MusicBrainzRecording {
	id: string;
	title: string;

	score: number;

	length: number;
	"first-release-date": string;

	releases: MusicBrainzRelease[];

	isrcs?: string[];
}

export interface MusicBrainzResponse {
	created: string;
	count: number;
	offset: number;
	recordings: MusicBrainzRecording[];
}
