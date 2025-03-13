<template>
	<ion-page>
		<AppHeader>
			<template #toolbar>
				<ion-buttons slot="start">
					<ion-back-button text="Library" />
				</ion-buttons>

				<ion-title>Songs</ion-title>

				<ion-progress-bar v-if="isLoading" type="indeterminate" />
			</template>
		</AppHeader>

		<ion-content :fullscreen="true">
			<ion-refresher slot="fixed" @ion-refresh="refreshLocalLibrary($event)">
				<ion-refresher-content />
			</ion-refresher>

			<SongItem v-for="(song, i) in librarySongs" :key="i" :song />
		</ion-content>

		<AppFooter />
	</ion-page>
</template>

<script lang="ts" setup>
import { onUpdated, ref } from "vue";

import AppFooter from "@/components/AppFooter.vue";
import AppHeader from "@/components/AppHeader.vue";
import SongItem from "@/components/SongItem.vue";
import {
	IonBackButton,
	IonButtons,
	IonContent,
	IonPage,
	IonProgressBar,
	IonRefresher,
	IonRefresherContent,
	IonTitle,
	RefresherCustomEvent,
} from "@ionic/vue";

import { AnySong, useMusicPlayer } from "@/stores/music-player";

const musicPlayer = useMusicPlayer();

const librarySongs = ref<AnySong[]>([]);
const isLoading = ref(false);

onUpdated(async () => {
	isLoading.value = true;
	librarySongs.value = await musicPlayer.services.librarySongs();
	isLoading.value = false;
});

async function refreshLocalLibrary(event: RefresherCustomEvent): Promise<void> {
	await musicPlayer.services.refreshLibrarySongs();
	librarySongs.value = await musicPlayer.services.librarySongs();
	await event.target.complete();
}
</script>
