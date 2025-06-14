export interface AcoustIDArtist {
	id: string;
	name: string;
}

export interface AcoustIDRelease {
	id: string;
	data: { year: number; month: number };

	track_count: number;
	medium_count: number;
	mediums: AcoustIDMedium[];
}

export interface AcoustIDReleaseGroup {
	id: string;
	title: string;
	type: "Album" | (string & {});
	releases: AcoustIDRelease[];
}

export interface AcoustIDTrack {
	artists: AcoustIDArtist[];
	id: string;
	position: number;
}

export interface AcoustIDMedium {
	format: string;
	position: number;
	track_count: number;
	tracks: AcoustIDTrack[];
}

export interface AcoustIDRecording {
	id: string;
	title: string;
	artists: AcoustIDArtist[];
	duration: number;

	releasegroups: AcoustIDReleaseGroup[];
}

export interface AcoustIDResult {
	id: string;
	score: number;
	recordings: AcoustIDRecording[];
}

export interface AcoustIDResponse {
	status: "ok";
	results: AcoustIDResult[];
}
