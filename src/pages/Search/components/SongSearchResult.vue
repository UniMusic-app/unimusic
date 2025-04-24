<script lang="ts" setup>
import { IonIcon, IonItem, useIonRouter } from "@ionic/vue";
import {
	addOutline as addIcon,
	hourglassOutline as hourglassIcon,
	playOutline as playIcon,
} from "ionicons/icons";

import GenericSongItem from "@/components/GenericSongItem.vue";
import { Song, SongPreview } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";

const musicPlayer = useMusicPlayer();
const ionRouter = useIonRouter();

type SearchResult = Song | SongPreview;
const { searchResult } = defineProps<{
	searchResult: SearchResult;
}>();

async function playNow(): Promise<void> {
	const song = await musicPlayer.services.retrieveSong(searchResult);
	await musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex);
}

async function playNext(): Promise<void> {
	const song = await musicPlayer.services.retrieveSong(searchResult);
	await musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex + 1);
}

async function addToQueue(): Promise<void> {
	const song = await musicPlayer.services.retrieveSong(searchResult);
	await musicPlayer.state.addToQueue(song);
}

function goToSong(): void {
	if (!searchResult) return;
	ionRouter.push(`/items/songs/${searchResult.type}/${searchResult.id}`);
}
</script>

<template>
	<GenericSongItem
		:title="searchResult.title"
		:kind="searchResult.kind"
		:artists="searchResult.artists"
		:artwork="searchResult.artwork"
		:type="searchResult.type"
		@item-click="playNow"
		@context-menu-click="goToSong"
	>
		<template #options>
			<ion-item :button="true" :detail="false" @click="playNow">
				<ion-icon aria-hidden="true" :icon="playIcon" slot="end" />
				Play now
			</ion-item>

			<ion-item :button="true" :detail="false" @click="playNext">
				<ion-icon aria-hidden="true" :icon="hourglassIcon" slot="end" />
				Play next
			</ion-item>

			<ion-item :button="true" :detail="false" @click="addToQueue">
				<ion-icon aria-hidden="true" :icon="addIcon" slot="end" />
				Add to queue
			</ion-item>
		</template>
	</GenericSongItem>
</template>
