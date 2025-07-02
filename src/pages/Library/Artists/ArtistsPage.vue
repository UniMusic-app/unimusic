<script lang="ts" setup>
import { useLocalStorage } from "@vueuse/core";
import { onUpdated, ref } from "vue";

import AppPage from "@/components/AppPage.vue";
import SkeletonItem from "@/components/SkeletonItem.vue";
import { IonList, IonRefresher, IonRefresherContent, RefresherCustomEvent } from "@ionic/vue";

import GenericArtistItem from "@/components/GenericArtistItem.vue";
import { Artist, ArtistPreview } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";

const musicPlayer = useMusicPlayer();

const libraryArtists = useLocalStorage<(Artist | ArtistPreview)[]>("libraryArtists", []);
const isLoading = ref(libraryArtists.value.length === 0);
onUpdated(async () => {
	isLoading.value = true;
	const artists: (Artist | ArtistPreview)[] = [];
	for await (const artist of musicPlayer.services.libraryArtists()) {
		artists.push(artist);
	}
	libraryArtists.value = artists;
	isLoading.value = false;
});

async function refreshArtistLibrary(event: RefresherCustomEvent): Promise<void> {
	isLoading.value = true;
	await musicPlayer.services.refreshLibraryArtists();
	libraryArtists.value.length = 0;
	for await (const song of musicPlayer.services.libraryArtists()) {
		libraryArtists.value.push(song);
	}
	isLoading.value = false;
	await event.target.complete();
}
</script>

<template>
	<AppPage title="Artists">
		<ion-refresher slot="fixed" @ion-refresh="refreshArtistLibrary">
			<ion-refresher-content />
		</ion-refresher>

		<ion-list v-if="!libraryArtists.length && isLoading" class="artists-list">
			<SkeletonItem v-for="i in 25" :key="i" />
		</ion-list>
		<ion-list v-else class="artists-list">
			<GenericArtistItem
				v-for="artist in libraryArtists"
				:title="artist.title"
				:type="artist.type"
				:artwork="artist.artwork"
				:router-link="`/items/artists/${artist.type}/${artist.id}`"
				:key="artist.id"
			/>
		</ion-list>
	</AppPage>
</template>

<style>
.artists-list {
	& > .skeleton-item {
		& > ion-thumbnail {
			--border-radius: 9999px;
		}
	}
}
</style>
