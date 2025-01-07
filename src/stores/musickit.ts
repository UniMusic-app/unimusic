import { MusicKitAuthorizationService } from "@/services/MusicKitAuthorization";
import { defineStore } from "pinia";
import { ref } from "vue";

export const useMusicKit = defineStore("MusicKit", () => {
	const music = ref<MusicKit.MusicKitInstance>();
	const authorized = ref(false);

	const authService = new MusicKitAuthorizationService();
	authService.addEventListener("authorized", () => (authorized.value = true));
	authService.addEventListener("unauthorized", () => (authorized.value = false));
	authService.passivelyAuthorize();

	return {
		music,
		authorized,
		authService,
	};
});
