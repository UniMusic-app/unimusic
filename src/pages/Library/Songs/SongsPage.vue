<script lang="ts" setup>
import { onUpdated, ref } from "vue";

import { IonList, IonRefresher, IonRefresherContent, RefresherCustomEvent } from "@ionic/vue";

import AppPage from "@/components/AppPage.vue";
import GenericSongItem from "@/components/GenericSongItem.vue";
import SkeletonItem from "@/components/SkeletonItem.vue";
import { AnySong, useMusicPlayer } from "@/stores/music-player";
import { useSessionStorage } from "@vueuse/core";

const musicPlayer = useMusicPlayer();

const librarySongs = useSessionStorage<AnySong[]>("librarySongs", []);
const isLoading = ref(false);

onUpdated(async () => {
	if (librarySongs.value.length) return;

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
			<SkeletonItem v-for="i in 25" :key="i" />
		</ion-list>
		<ion-list v-else>
			<GenericSongItem
				v-for="(song, i) in librarySongs"
				:router-link="`/library/songs/${song.type}/${song.id}`"
				:key="i"
				:title="song.title"
				:artists="song.artists"
				:artwork="song.artwork"
				:type="song.type"
			/>
		</ion-list>
	</AppPage>
</template>
