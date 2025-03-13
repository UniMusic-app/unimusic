import { defineStore } from "pinia";
import { computed, reactive } from "vue";

import { MusicPlayerService, SongSearchResult } from "@/services/MusicPlayer/MusicPlayerService";

import { LocalMusicPlayerService } from "@/services/MusicPlayer/LocalMusicPlayerService";
import { MusicKitMusicPlayerService } from "@/services/MusicPlayer/MusicKitMusicPlayerService";
import { YouTubeMusicPlayerService } from "@/services/MusicPlayer/YouTubeMusicPlayerService";

import { AnySong } from "@/stores/music-player";

import { Maybe } from "@/utils/types";

export const useMusicServices = defineStore("MusicServices", () => {
	const registeredServices = reactive<Record<string, MusicPlayerService>>({});
	const enabledServices = computed<MusicPlayerService[]>(() =>
		Object.values(registeredServices).filter((service) => service.enabled.value),
	);

	// #region Actions for managing services
	function registerService(service: MusicPlayerService): void {
		registeredServices[service.type] = service;
	}

	function getService(type: string): Maybe<MusicPlayerService> {
		const service = registeredServices[type];
		if (service?.enabled?.value) {
			return service;
		}
	}
	// #endregion

	// #region Actions for calling service methods
	function withAllServices<T>(callback: (service: MusicPlayerService) => T): Promise<Awaited<T>[]> {
		return Promise.all(enabledServices.value.map(callback));
	}

	async function searchHints(term: string): Promise<string[]> {
		const allHints = await withAllServices((service) => service.searchHints(term));
		return allHints.flat();
	}

	async function searchSongs(term: string, offset = 0): Promise<SongSearchResult[]> {
		const allResults = await withAllServices((service) => service.searchSongs(term, offset));
		return allResults.flat();
	}

	async function librarySongs(offset = 0): Promise<AnySong[]> {
		const allSongs = await withAllServices((service) => service.librarySongs(offset));
		return allSongs.flat();
	}

	async function refreshLibrarySongs(): Promise<void> {
		await withAllServices((service) => service.refreshLibrarySongs());
	}

	async function refreshSong(song: AnySong): Promise<void> {
		await getService(song.type)?.refreshSong(song);
	}

	async function getSongFromSearchResult(searchResult: SongSearchResult): Promise<AnySong> {
		const service = getService(searchResult.type)!;
		const song = await service.getSongFromSearchResult(searchResult);
		return song;
	}
	// #endregion

	registerService(new MusicKitMusicPlayerService());
	registerService(new YouTubeMusicPlayerService());
	registerService(new LocalMusicPlayerService());

	return {
		registeredServices,
		enabledServices,

		registerService,
		getService,

		withAllServices,
		searchHints,
		searchSongs,
		librarySongs,
		refreshLibrarySongs,
		refreshSong,
		getSongFromSearchResult,
	};
});
