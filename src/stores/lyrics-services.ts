import { Lyrics, LyricsService } from "@/services/Lyrics/LyricsService";
import { Song, SongPreview, SongType } from "@/services/Music/objects";
import { Maybe } from "@/utils/types";
import { defineStore } from "pinia";
import { computed, reactive } from "vue";

export const useLyricsServices = defineStore("LyricsServices", () => {
	const registeredServices = reactive<Record<string, LyricsService>>({});
	const enabledServices = computed<LyricsService[]>(() =>
		Object.values(registeredServices)
			.filter((service) => service.enabled.value)
			.sort((a, b) => a.order.value - b.order.value || a.name.localeCompare(b.name)),
	);

	function registerService(service: LyricsService): void {
		registeredServices[service.name] = service;
	}

	async function getLyricsFromSong<Type extends SongType>(
		song: Song<Type> | SongPreview<Type>,
	): Promise<Maybe<Lyrics>> {
		for (const service of enabledServices.value) {
			if (!service.handleGetLyricsFromSong) continue;

			const lyrics = service.getLyricsFromSong(song);
			if (lyrics) return lyrics;
		}
	}

	async function getLyricsFromISRC(isrc: string): Promise<Maybe<Lyrics>> {
		for (const service of enabledServices.value) {
			if (!service.handleGetLyricsFromISRC) continue;

			const lyrics = service.getLyricsFromISRC(isrc);
			if (lyrics) return lyrics;
		}
	}

	void import("@/services/Lyrics/LRCLIBLyricsService").then((module) =>
		registerService(new module.LRCLIBLyricsService()),
	);

	return {
		registeredServices,
		enabledServices,
		registerService,

		getLyricsFromSong,
		getLyricsFromISRC,
	};
});
