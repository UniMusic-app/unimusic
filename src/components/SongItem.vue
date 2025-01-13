<template>
	<ion-item>
		<ion-thumbnail slot="start">
			<img :src="artworkUrl" :alt="`Artwork for song '${songName}'`" />
		</ion-thumbnail>

		<ion-label class="ion-text-nowrap">
			<h2>{{ songName }}</h2>
			<ion-note>
				Song
				<ion-icon :icon="musicalNoteIcon" />
				{{ songArtist }}
			</ion-note>
		</ion-label>

		<ion-buttons slot="end">
			<ion-button @click="emit('play')">
				<ion-icon slot="icon-only" :icon="playIcon" />
			</ion-button>
			<ion-button @click="emit('addToQueue')">
				<ion-icon slot="icon-only" :icon="addIcon" />
			</ion-button>
		</ion-buttons>
	</ion-item>
</template>

<script setup lang="ts">
import {
	IonItem,
	IonThumbnail,
	IonLabel,
	IonButtons,
	IonButton,
	IonIcon,
	IonNote,
} from "@ionic/vue";
import { musicalNote as musicalNoteIcon, play as playIcon, add as addIcon } from "ionicons/icons";

const emit = defineEmits<{ addToQueue: []; play: [] }>();

const { songName, songArtist, artworkUrl } = defineProps<{
	artworkUrl: string;
	songArtist: string;
	songName: string;
}>();
</script>

<style scoped>
ion-label {
	& > h2 {
		font-size: 1rem;
		font-weight: bold;
		display: block;
	}

	& > ion-note {
		font-size: 0.8em;
	}
}
</style>
