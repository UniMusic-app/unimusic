import { WebPlugin } from "@capacitor/core";
import {
	MediaSessionPlugin,
	MediaSessionPluginMetadata,
	MediaSessionPluginPlaybackState,
} from "../MediaSession";

// Web implementation of MediaSession
export class MediaSession extends WebPlugin implements MediaSessionPlugin {
	#metadata: MediaSessionPluginMetadata | undefined;

	initialize(): void {}

	setMetadata(metadata: MediaSessionPluginMetadata): void {
		this.#metadata = metadata;

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

		navigator.mediaSession.setPositionState({
			position: 0,
			duration: metadata.duration,
		});
	}

	setPlaybackState({ state, elapsed }: MediaSessionPluginPlaybackState): void {
		if (state === "none") {
			navigator.mediaSession.metadata = null;
		} else if (this.#metadata?.duration) {
			console.log("Elapsed", elapsed, "/", this.#metadata.duration);
			navigator.mediaSession.setPositionState({
				position: elapsed,
				duration: this.#metadata.duration,
			});
		}

		navigator.mediaSession.playbackState = state;
	}
}
