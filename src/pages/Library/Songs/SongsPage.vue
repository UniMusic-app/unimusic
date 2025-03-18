<script lang="ts" setup>
import { onUpdated, ref } from "vue";

import SongItem from "@/components/SongItem.vue";
import { IonList, IonRefresher, IonRefresherContent, RefresherCustomEvent } from "@ionic/vue";

import AppPage from "@/components/AppPage.vue";
import SkeletonItem from "@/components/SkeletonItem.vue";
import { AnySong, useMusicPlayer } from "@/stores/music-player";

const musicPlayer = useMusicPlayer();

const librarySongs = ref<AnySong[]>([]);
const isLoading = ref(true);

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

<template>
	<AppPage title="Songs" back-button="Library">
		<ion-refresher slot="fixed" @ion-refresh="refreshLocalLibrary($event)">
			<ion-refresher-content />
		</ion-refresher>

		<ion-list v-if="isLoading">
			<SkeletonItem v-for="i in 10" :key="i" />
		</ion-list>
		<ion-list v-else>
			<SongItem v-for="(song, i) in librarySongs" :key="i" :song />
		</ion-list>
	</AppPage>
</template>
