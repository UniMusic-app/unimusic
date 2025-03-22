<script lang="ts" setup>
import { IonIcon, IonItem, IonItemDivider, useIonRouter } from "@ionic/vue";
import { listOutline as addToQueueIcon, hourglassOutline as playNextIcon } from "ionicons/icons";

import { AnySong, useMusicPlayer } from "@/stores/music-player";
import GenericSongItem from "./GenericSongItem.vue";

const { song } = defineProps<{ song: AnySong }>();

const musicPlayer = useMusicPlayer();
const router = useIonRouter();

async function play(): Promise<void> {
	await musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex);
}

async function playNext(): Promise<void> {
	await musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex + 1);
}

async function addToQueue(): Promise<void> {
	await musicPlayer.state.addToQueue(song);
}

function goToSong(): void {
	router.push(`/library/songs/${song.type}/${song.id}`);
}
</script>

<template>
	<!-- TODO: Go to song on context menu click-->
	<GenericSongItem
		:title="song.title"
		:artists="song.artists"
		:artwork="song.artwork"
		:type="song.type"
		@item-click="play"
		@context-menu-click="goToSong"
	>
		<template #options>
			<ion-item lines="full" button :detail="false" @click="playNext">
				Play Next
				<ion-icon aria-hidden="true" :icon="playNextIcon" slot="end" />
			</ion-item>
			<ion-item lines="full" button :detail="false" @click="addToQueue">
				Add to Queue
				<ion-icon aria-hidden="true" :icon="addToQueueIcon" slot="end" />
			</ion-item>
			<ion-item-divider />
		</template>
	</GenericSongItem>
</template>
q
