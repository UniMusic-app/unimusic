import { MusicKitAuthorizationService } from "@/services/MusicKitAuthorization";
import { defineStore } from "pinia";
import { ref } from "vue";

export const useMusicKit = defineStore("MusicKit", () => {
	const { promise: musicPromise, resolve: resolveMusicPromise } =
		Promise.withResolvers<MusicKit.MusicKitInstance>();
	const authorized = ref(false);

	const authService = new MusicKitAuthorizationService();
	authService.addEventListener("authorized", () => {
		resolveMusicPromise(MusicKit.getInstance()!);
		authorized.value = true;
	});
	authService.addEventListener("unauthorized", () => (authorized.value = false));
	authService.passivelyAuthorize();

	async function withMusic<T>(callback: (music: MusicKit.MusicKitInstance) => T): Promise<T> {
		const music = await musicPromise;
		return callback(music);
	}

	return {
		music: musicPromise,
		withMusic,

		authorized,
		authService,
	};
});
