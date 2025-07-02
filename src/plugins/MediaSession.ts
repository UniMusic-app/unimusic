import { registerPlugin } from "@capacitor/core";

export interface MediaSessionPluginMetadata {
	title?: string;
	artist?: string;
	album?: string;
	duration?: number;
	artwork?: string;
}

export interface MediaSessionPluginPlaybackState {
	state: MediaSessionPlaybackState;
	elapsed: number;
}

export interface MediaSessionPlugin {
	initialize(): void | Promise<void>;
	setMetadata(metadata: MediaSessionPluginMetadata): void | Promise<void>;
	setPlaybackState(state: MediaSessionPluginPlaybackState): void | Promise<void>;
}

export interface MediaSessionPluginActionEvent extends Event {
	action: "play" | "pause" | "skipToPrevious" | "skipToNext";
}

export interface MediaSessionPluginSeekEvent extends Event {
	action: "seekTo";
	position: number;
}

export type MediaSessionPluginEvent = MediaSessionPluginActionEvent | MediaSessionPluginSeekEvent;

async function webImplementation(): Promise<
	InstanceType<typeof import("./MediaSession/web").MediaSession>
> {
	const { MediaSession } = await import("./MediaSession/web");
	return new MediaSession();
}

const MediaSession = registerPlugin<MediaSessionPlugin>("MediaSession", {
	ios: webImplementation,
	web: webImplementation,
});

export default MediaSession;
