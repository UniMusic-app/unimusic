<template>
	<ion-item>
		<ion-thumbnail v-if="artworkUrl" slot="start">
			<img :src="artworkUrl" :alt="`Artwork for song '${title}' by ${artist}`" />
		</ion-thumbnail>

		<ion-label class="ion-text-nowrap">
			<h2>{{ title ?? "Unknown title" }}</h2>
			<ion-note>
				Song
				<ion-icon :icon="musicalNoteIcon" />
				{{ artist }}
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

const { title, artist, artworkUrl } = defineProps<{
	artworkUrl?: string;
	artist?: string;
	title?: string;
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
