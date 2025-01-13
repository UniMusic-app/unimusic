<template>
	<ion-item button @click.self="modalOpen = true" v-if="currentSong?.id">
		<ion-thumbnail slot="start">
			<img :src="currentSong.artworkUrl" :alt="`Artwork for song '${currentSong.name}'`" />
		</ion-thumbnail>

		<ion-label class="ion-text-nowrap">
			{{ currentSong.name }}
		</ion-label>

		<ion-buttons slot="end">
			<ion-button :disabled="!hasPrevious" @click="musicPlayer.skipPrevious">
				<ion-icon :icon="skipPreviousIcon" slot="icon-only" />
			</ion-button>
			<ion-button @click="musicPlayer.togglePlay">
				<ion-icon :icon="playing ? pauseIcon : playIcon" slot="icon-only" />
			</ion-button>
			<ion-button :disabled="!hasNext" @click="musicPlayer.skipNext">
				<ion-icon :icon="skipNextIcon" slot="icon-only" />
			</ion-button>
		</ion-buttons>
	</ion-item>

	<ion-modal
		:is-open="modalOpen"
		:initial-breakpoint="1"
		:breakpoints="[0, 1]"
		@willDismiss="modalOpen = false"
	>
		<MusicPlayer />
	</ion-modal>
</template>

<script setup lang="ts">
import { storeToRefs } from "pinia";
import { ref } from "vue";

import {
	play as playIcon,
	pause as pauseIcon,
	playSkipBack as skipPreviousIcon,
	playSkipForward as skipNextIcon,
} from "ionicons/icons";
import {
	IonItem,
	IonThumbnail,
	IonLabel,
	IonButton,
	IonButtons,
	IonIcon,
	IonModal,
} from "@ionic/vue";

import { useMusicPlayer } from "@/stores/music-player";
import MusicPlayer from "@/components/MusicPlayer.vue";

const musicPlayer = useMusicPlayer();
const { playing, currentSong, hasPrevious, hasNext } = storeToRefs(musicPlayer);

const modalOpen = ref(false);
</script>

<style scoped>
ion-label {
	font-weight: bold;
}

ion-thumbnail {
	--border-radius: 12px;
}

ion-item {
	& > ion-thumbnail,
	ion-label {
		pointer-events: none;
	}
}
</style>
