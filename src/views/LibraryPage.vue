<template>
	<ion-page>
		<app-header>
			<template #toolbar>
				<ion-title>Library</ion-title>
			</template>
		</app-header>

		<ion-content class="ion-padding">
			<ion-refresher slot="fixed" @ionRefresh="refreshLocalLibrary($event)">
				<ion-refresher-content></ion-refresher-content>
			</ion-refresher>

			{{ songs.length }}
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
import LocalMusicPlugin, { type LocalMusicSong } from "@/plugins/LocalMusicPlugin";
import SongItem from "@/components/SongItem.vue";

const songs = ref<LocalMusicSong[]>([]);

onMounted(async () => {
	songs.value = await LocalMusicPlugin.getSongs();
});

async function refreshLocalLibrary(event: RefresherCustomEvent) {
	songs.value = await LocalMusicPlugin.getSongs(true);
	await event.target.complete();
}
</script>
