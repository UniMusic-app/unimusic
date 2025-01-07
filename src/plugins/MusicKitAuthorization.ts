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

export default MusicKitAuthorization;
