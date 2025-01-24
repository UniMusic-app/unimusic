<template>
	<ion-item button :detail="false" @click.self="play">
		<ion-thumbnail v-if="artworkUrl" slot="start">
			<img :src="artworkUrl" :alt="`Artwork for song '${title}' by ${artist}`" />
		</ion-thumbnail>

		<ion-label class="ion-text-nowrap">
			<h2>{{ title ?? "Unknown title" }}</h2>
			<ion-note>
				<ion-icon :icon="compassIcon" />
				{{ songTypeDisplayName(song) }}
				<ion-icon :icon="musicalNoteIcon" />
				{{ artist }}
			</ion-note>
		</ion-label>

		<ion-buttons slot="end">
			<ion-button>
				<ion-icon slot="icon-only" :icon="ellipsisHorizontal" />
				<!-- TODO: Popover with options -->
			</ion-button>
		</ion-buttons>
	</ion-item>
</template>

<script setup lang="ts">
import { AnySong, useMusicPlayer } from "@/stores/music-player";
import { songTypeDisplayName } from "@/utils/songs";
import {
	IonItem,
	IonThumbnail,
	IonLabel,
	IonButtons,
	IonButton,
	IonIcon,
	IonNote,
} from "@ionic/vue";
import {
	musicalNote as musicalNoteIcon,
	ellipsisHorizontal,
	compass as compassIcon,
} from "ionicons/icons";

const { song } = defineProps<{ song: AnySong }>();
const { title, artist, artworkUrl } = song;

const musicPlayer = useMusicPlayer();

function play() {
	musicPlayer.add(song, musicPlayer.queueIndex);
}
</script>

<style scoped>
ion-item {
	& > ion-thumbnail {
		pointer-events: none;
	}

	& > ion-label {
		pointer-events: none;

		& > h2 {
			font-size: 1rem;
			font-weight: bold;
			display: block;
		}

		& > ion-note {
			display: flex;
			align-items: center;
			gap: 0.5ch;
			font-size: 0.8em;
		}
	}
}
</style>
