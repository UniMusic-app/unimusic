<template>
	<ion-page>
		<app-header>
			<template #toolbar>
				<ion-title>Library</ion-title>
			</template>
		</app-header>

		<ion-content :fullscreen="true" class="ion-padding">
			<ion-button @click="getSongs">get songs</ion-button>

			<ion-list v-for="song in songs" :key="song.id">
				<library-song-item :song />
			</ion-list>
		</ion-content>

		<app-footer />
	</ion-page>
</template>

<script setup lang="ts">
import { IonPage, IonTitle, IonContent, IonButton, IonList } from "@ionic/vue";
import AppHeader from "@/components/AppHeader.vue";
import AppFooter from "@/components/AppFooter.vue";
import AudioLibrary, { AudioLibrarySong } from "@/plugins/AudioLibrary";
import { ref } from "vue";
import LibrarySongItem from "@/components/SongItem/LibrarySongItem.vue";

const songs = ref<AudioLibrarySong[]>([]);
async function getSongs() {
	songs.value = (await AudioLibrary.getSongs()).songs;
}
</script>
