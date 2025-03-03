import MusicKitAuthorizationPlugin from "@/plugins/MusicKitAuthorization";
import { AuthorizationService } from "@/services/Authorization/AuthorizationService";
import { Maybe } from "@/utils/types";

interface MusicKitTokens {
	developerToken: string;
	musicUserToken: string;
}

export class MusicKitAuthorizationService extends AuthorizationService<MusicKitTokens> {
	logName = "MusicKitAuthorizationService";
	logColor = "#ff7080";

	key = "MusicKit";

	constructor() {
		super();
	}

	async initialize(
		developerToken: string,
		musicUserToken: string,
	): Promise<MusicKit.MusicKitInstance> {
		this.log("initialize");
		const music = await MusicKit.configure({
			developerToken: developerToken || import.meta.env.VITE_DEVELOPER_TOKEN,
			app: {
				name: import.meta.env.VITE_APP_NAME,
				build: import.meta.env.VITE_APP_VERSION,
			},
		});
		music.musicUserToken = musicUserToken;
		return music;
	}

	async handlePassivelyAuthorize(): Promise<Maybe<MusicKitTokens>> {
		if (!globalThis.MusicKit) {
			this.log("MusicKit not yet initialized, retrying after it gets loaded...");

			return new Promise((resolve) => {
				document.addEventListener("musickitloaded", () => resolve(this.passivelyAuthorize()), {
					once: true,
				});
			});
		}

		const music = MusicKit.getInstance();
		if (music?.isAuthorized) {
			this.log("Already authorized");
			const tokens: MusicKitTokens = {
				developerToken: music.developerToken,
				musicUserToken: music.musicUserToken!,
			};
			return tokens;
		}

		const tokens = await this.getRemembered();
		if (tokens) {
			this.log("Restoring session");
			const music = await this.initialize(tokens.developerToken, tokens.musicUserToken);
			if (music.isAuthorized) {
				const tokens: MusicKitTokens = {
					developerToken: music.developerToken,
					musicUserToken: music.musicUserToken!,
				};
				return tokens;
			}
		}
	}

	async handleAuthorize(): Promise<MusicKitTokens> {
		let tokens = await this.passivelyAuthorize();
		if (tokens) return tokens;

		tokens = await MusicKitAuthorizationPlugin.authorize();
		const musicKitInstance = await this.initialize(tokens.developerToken, tokens.musicUserToken);

		if (musicKitInstance.isAuthorized) {
			await this.remember(tokens);
			return tokens;
		} else {
			throw new Error("Failed to authorize MusicKit");
		}
	}

	async handleUnauthorize(): Promise<void> {
		const music = MusicKit.getInstance();
		if (music) await music.unauthorize();
	}
}
