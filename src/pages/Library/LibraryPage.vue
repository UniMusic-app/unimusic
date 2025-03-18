<template>
	<AppPage title="Library">
		<ion-item router-link="/library/playlists">
			<ion-icon color="primary" :icon="playlistsIcon" class="padded-icon" size="large" slot="start" />
			<ion-label>Playlists</ion-label>
		</ion-item>

		<ion-item router-link="/library/albums">
			<ion-icon color="primary" :icon="albumsIcon" class="padded-icon" size="large" slot="start" />
			<ion-label>Albums</ion-label>
		</ion-item>

		<ion-item router-link="/library/songs">
			<ion-icon color="primary" :icon="songsIcon" class="padded-icon" size="large" slot="start" />
			<ion-label>Songs</ion-label>
		</ion-item>
	</AppPage>
</template>

<script setup lang="ts">
import AppPage from "@/components/AppPage.vue";

import { IonIcon, IonItem, IonLabel } from "@ionic/vue";
import {
	albumsOutline as albumsIcon,
	musicalNotesOutline as playlistsIcon,
	musicalNoteOutline as songsIcon,
} from "ionicons/icons";
</script>

<style>
.padded-icon {
	padding: 4px;
}
</style>
