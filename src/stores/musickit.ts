import { MusicKitAuthorizationService } from "@/services/MusicKitAuthorization";
import { defineStore } from "pinia";
import { ref, watch } from "vue";

export const useMusicKit = defineStore("MusicKit", () => {
	const music = ref<MusicKit.MusicKitInstance>();
	const authorized = ref(false);

	const authService = new MusicKitAuthorizationService();
	authService.addEventListener("authorized", () => {
		music.value = MusicKit.getInstance();
		authorized.value = true;
	});
	authService.addEventListener("unauthorized", () => (authorized.value = false));
	authService.passivelyAuthorize();

	return {
		music,
		authorized,
		authService,

		withMusic<T>(callback: (music: MusicKit.MusicKitInstance) => T): Promise<T> {
			return new Promise((resolve) => {
				if (music.value) {
					resolve(callback(music.value));
				} else {
					watch(music, (music) => resolve(callback(music!)), { once: true });
				}
			});
		},
	};
});
