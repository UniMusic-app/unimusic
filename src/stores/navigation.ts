import { useIonRouter } from "@ionic/vue";
import { defineStore } from "pinia";

import { Song, SongPreview } from "@/services/Music/objects";

export const useNavigation = defineStore("Navigation", () => {
	const ionRouter = useIonRouter();

	function goToSong(song: Song | SongPreview): void {
		if (!song.id) {
			// TODO: Error toast when song has no id
			return;
		}

		ionRouter.push(`/items/songs/${song.type}/${song.id}`);
	}

	return {
		goToSong,
	};
});
