<script lang="ts" setup>
import { IonRefresher, IonRefresherContent, RefresherCustomEvent } from "@ionic/vue";
import { onUpdated, ref } from "vue";

import AppPage from "@/components/AppPage.vue";

import GenericAlbumCard from "@/components/GenericAlbumCard.vue";
import SkeletonCard from "@/components/SkeletonCard.vue";
import { Album, AlbumPreview } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { useLocalStorage } from "@vueuse/core";

const musicPlayer = useMusicPlayer();

const libraryAlbums = useLocalStorage<(Album | AlbumPreview)[]>("libraryAlbums", []);
const isLoading = ref(libraryAlbums.value.length === 0);
onUpdated(async () => {
	isLoading.value = true;
	const albums: (Album | AlbumPreview)[] = [];
	for await (const album of musicPlayer.services.libraryAlbums()) {
		albums.push(album);
	}
	libraryAlbums.value = albums;
	isLoading.value = false;
});

async function refreshAlbumLibrary(event: RefresherCustomEvent): Promise<void> {
	isLoading.value = true;
	await musicPlayer.services.refreshLibraryAlbums();
	libraryAlbums.value.length = 0;
	for await (const album of musicPlayer.services.libraryAlbums()) {
		libraryAlbums.value.push(album);
	}
	isLoading.value = false;
	await event.target.complete();
}
</script>

<template>
	<AppPage title="Albums" back-button="Library">
		<ion-refresher slot="fixed" @ion-refresh="refreshAlbumLibrary">
			<ion-refresher-content />
		</ion-refresher>

		<div v-if="!libraryAlbums.length && isLoading" class="album-cards">
			<SkeletonCard v-for="i in 25" :key="i" />
		</div>
		<div v-else class="album-cards">
			<GenericAlbumCard
				:album
				class="album-card"
				:router-link="`/items/albums/album/${album.type}/${album.id}`"
				v-for="album in libraryAlbums"
				:key="album.id"
				:artwork="album.artwork"
				:title="album.title"
				:artists="album.artists"
			/>
		</div>
	</AppPage>
</template>

<style scoped>
@keyframes show-up {
	from {
		opacity: 0%;
	}

	to {
		opacity: 100%;
	}
}

.album-cards {
	display: grid;
	width: 100vw;
	padding: 8px;
	grid-template-rows: auto;

	justify-content: center;
	align-items: end;

	animation: show-up 250ms ease-in;

	--gap: 8px;
	--columns: 1;
	@media screen and (min-width: 320px) {
		--columns: 2;
	}
	@media screen and (min-width: 640px) {
		--gap: 16px;
		--columns: 3;
	}
	@media screen and (min-width: 960px) {
		--columns: 4;
	}
	@media screen and (min-width: 960px) {
		--gap: 24px;
		--columns: 4;
	}
	gap: var(--gap);
	grid-template-columns: repeat(var(--columns), calc(100% / var(--columns) - var(--gap)));

	:global(& .album-card) {
		width: 100%;
	}
}

.skeleton-card {
	margin: 0;
	background: transparent;
	box-shadow: none;
	border-radius: 0;

	& > .local-img {
		border-radius: 8px;
	}

	& > ion-card-header {
		padding: 8px;

		& > ion-card-title {
			font-size: 1rem;
			font-weight: 550;
			text-overflow: ellipsis;
			overflow: hidden;
		}

		& > ion-card-subtitle {
			font-size: 0.75rem;
			font-weight: 400;
			text-overflow: ellipsis;
			overflow: hidden;
		}
	}
}
</style>
