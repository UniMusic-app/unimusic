<template>
	<song-menu :song>
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
	</song-menu>
</template>

<script setup lang="ts">
import { IonItem, IonIcon } from "@ionic/vue";
import {
	playOutline as playIcon,
	hourglassOutline as hourglassIcon,
	addOutline as addIcon,
} from "ionicons/icons";
import SongMenu from "@/components/SongMenu.vue";

import { AnySong, useMusicPlayer } from "@/stores/music-player";

const { song } = defineProps<{ song: AnySong }>();

const musicPlayer = useMusicPlayer();

function playNow() {
	musicPlayer.addToQueue(song, musicPlayer.queueIndex);
}

function playNext() {
	musicPlayer.addToQueue(song, musicPlayer.queueIndex + 1);
}

function addToQueue() {
	musicPlayer.addToQueue(song);
}
</script>
