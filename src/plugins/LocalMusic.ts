import { registerPlugin } from "@capacitor/core";

export interface LocalSongInfo {
	id: string;
	path: string;
}

export interface LocalMusicPlugin {
	getSongs(): Promise<{ songs: LocalSongInfo[] }>;
}

const LocalMusic = registerPlugin<LocalMusicPlugin>("LocalMusic", {});

export default LocalMusic;
