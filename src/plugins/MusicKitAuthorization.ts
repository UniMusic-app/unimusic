import { registerPlugin } from "@capacitor/core";

export interface MusicKitAuthorizationPlugin {
	authorize(): Promise<{ developerToken: string; musicUserToken: string }>;
}

const MusicKitAuthorization = registerPlugin<MusicKitAuthorizationPlugin>("MusicKitAuthorization", {
	web: () =>
		import("./MusicKitAuthorization/web").then(
			({ MusicKitAuthorization }) => new MusicKitAuthorization(),
		),
});

export default {
	async authorize(): Promise<MusicKit.MusicKitInstance> {
		const instance = globalThis.MusicKit.getInstance();
		if (instance?.isAuthorized) return instance;

		const { developerToken, musicUserToken } = await MusicKitAuthorization.authorize();

		const music = await MusicKit.configure({
			developerToken: developerToken || import.meta.env.VITE_DEVELOPER_TOKEN,
			app: {
				name: import.meta.env.VITE_APP_NAME,
				build: import.meta.env.VITE_APP_VERSION,
			},
		});

		music.musicUserToken = musicUserToken;

		return music;
	},
};
