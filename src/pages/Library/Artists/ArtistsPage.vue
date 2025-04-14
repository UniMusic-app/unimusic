<script lang="ts" setup>
import { useSessionStorage } from "@vueuse/core";
import { onUpdated, ref } from "vue";

import AppPage from "@/components/AppPage.vue";
import LocalImg from "@/components/LocalImg.vue";
import SkeletonItem from "@/components/SkeletonItem.vue";
import { IonItem, IonList } from "@ionic/vue";

import { Artist, ArtistPreview } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";

const musicPlayer = useMusicPlayer();

const libraryArtists = useSessionStorage<(Artist | ArtistPreview)[]>("libraryArtists", []);
const isLoading = ref(libraryArtists.value.length === 0);
onUpdated(async () => {
	if (!libraryArtists.value.length) {
		console.log("getting those mfs");
		isLoading.value = true;
		for await (const artist of musicPlayer.services.libraryArtists()) {
			console.log(artist);
			libraryArtists.value.push(artist);
		}
		console.log("thats all");
		isLoading.value = false;
	}
});
</script>

<template>
	<AppPage title="Artists" back-button="Library">
		<ion-list v-if="isLoading" class="songs-list">
			<SkeletonItem v-for="i in 25" :key="i" />
		</ion-list>
		<ion-list v-else class="songs-list">
			<ion-item v-for="artist in libraryArtists" :key="artist.id">
				<LocalImg :src="artist.artwork" />
				{{ artist.title }}
			</ion-item>
		</ion-list>
	</AppPage>
</template>
