<script lang="ts" setup>
import { createMetadataModal } from "@/components/SongMetadataModal.vue";
import { IonIcon, IonItem, IonItemDivider } from "@ionic/vue";
import {
	listOutline as addToQueueIcon,
	documentOutline as modifyMetadataIcon,
	hourglassOutline as playNextIcon,
} from "ionicons/icons";

import { AnySong, useMusicPlayer } from "@/stores/music-player";
import GenericSongItem from "./GenericSongItem.vue";

const { song } = defineProps<{ song: AnySong }>();

const musicPlayer = useMusicPlayer();

async function play(): Promise<void> {
	await musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex);
}

async function playNext(): Promise<void> {
	await musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex + 1);
}

async function addToQueue(): Promise<void> {
	await musicPlayer.state.addToQueue(song);
}

async function modifyMetadata(): Promise<void> {
	const modal = await createMetadataModal(song);
	await modal.present();
	await modal.onDidDismiss();
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
			<ion-item lines="full" button :detail="false" @click="modifyMetadata">
				Modify Metadata
				<ion-icon aria-hidden="true" :icon="modifyMetadataIcon" slot="end" />
			</ion-item>
		</template>
	</GenericSongItem>
</template>
