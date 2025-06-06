import { registerPlugin } from "@capacitor/core";

export interface MusicKitTokens {
	developerToken: string;
	musicUserToken: string;
}

export interface MusicKitAuthorizationPlugin {
	authorize(): Promise<MusicKitTokens>;
}

const MusicKitAuthorization = registerPlugin<MusicKitAuthorizationPlugin>("MusicKitAuthorization", {
	async web() {
		const { MusicKitAuthorization } = await import("./MusicKitAuthorization/web");
		return new MusicKitAuthorization();
	},
});

export default MusicKitAuthorization;
