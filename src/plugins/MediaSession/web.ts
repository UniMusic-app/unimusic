import { WebPlugin } from "@capacitor/core";
import {
	MediaSessionPlugin,
	MediaSessionPluginMetadata,
	MediaSessionPluginPlaybackState,
} from "../MediaSession";

// Web implementation of MediaSession
export class MediaSession extends WebPlugin implements MediaSessionPlugin {
	initialize(): void {}

	setMetadata(metadata: MediaSessionPluginMetadata): void {
		let artwork: [MediaImage] | undefined;
		if (metadata.artwork) {
			artwork = [{ src: metadata.artwork }];
		}

		navigator.mediaSession.metadata = new window.MediaMetadata({
			title: metadata.title,
			album: metadata.album,
			artist: metadata.artist,
			artwork: artwork,
		});
	}

	setPlaybackState({ state }: MediaSessionPluginPlaybackState): void {
		switch (state) {
			case "none":
				navigator.mediaSession.metadata = null;
			default:
				navigator.mediaSession.playbackState = state;
		}
	}
}
