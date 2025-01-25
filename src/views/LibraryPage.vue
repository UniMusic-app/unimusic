<template>
	<ion-page>
		<app-header>
			<template #toolbar>
				<ion-title>Library</ion-title>
			</template>
		</app-header>

		<ion-content :fullscreen="true">
			<ion-refresher slot="fixed" @ionRefresh="refreshLocalLibrary($event)">
				<ion-refresher-content></ion-refresher-content>
			</ion-refresher>

			<song-item v-for="(song, i) in songs" :key="song.id + i" :song />
		</ion-content>

		<app-footer />
	</ion-page>
</template>

<script setup lang="ts">
import {
	IonPage,
	IonTitle,
	IonContent,
	IonRefresher,
	IonRefresherContent,
	RefresherCustomEvent,
} from "@ionic/vue";
import AppHeader from "@/components/AppHeader.vue";
import AppFooter from "@/components/AppFooter.vue";
import { onMounted, ref } from "vue";
import { AnySong, useMusicPlayer } from "@/stores/music-player";
import SongItem from "@/components/SongItem.vue";

const musicPlayer = useMusicPlayer();

const songs = ref<AnySong[]>([]);

onMounted(async () => {
	songs.value = await musicPlayer.librarySongs();
});

async function refreshLocalLibrary(event: RefresherCustomEvent) {
	await musicPlayer.refreshServices();
	songs.value = await musicPlayer.librarySongs();
	await event.target.complete();
}
</script>
