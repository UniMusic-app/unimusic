<script lang="ts" setup>
import LocalImg from "@/components/LocalImg.vue";

import {
	IonButton,
	IonButtons,
	IonIcon,
	IonItem,
	IonLabel,
	IonList,
	IonRefresher,
	IonRefresherContent,
	RefresherCustomEvent,
} from "@ionic/vue";
import {
	add as addIcon,
	downloadOutline as importIcon,
	listOutline as playlistIcon,
} from "ionicons/icons";

import { useMusicPlayer } from "@/stores/music-player";

import AppPage from "@/components/AppPage.vue";
import SkeletonItem from "@/components/SkeletonItem.vue";
import { Playlist, PlaylistPreview } from "@/services/Music/objects";
import { useLocalStorage } from "@vueuse/core";
import { onMounted, ref } from "vue";
import PlaylistAddModal from "./components/PlaylistAddModal.vue";
import PlaylistImportModal from "./components/PlaylistImportModal.vue";

const musicPlayer = useMusicPlayer();

const libraryPlaylists = useLocalStorage<(Playlist | PlaylistPreview)[]>("libraryPlaylists", []);
const isLoading = ref(libraryPlaylists.value.length === 0);
onMounted(async () => {
	isLoading.value = true;

	const playlists: (Playlist | PlaylistPreview)[] = [];
	for await (const playlist of musicPlayer.services.libraryPlaylists()) {
		playlists.push(playlist);
	}
	playlists.push(...musicPlayer.state.getAllPlaylists());

	libraryPlaylists.value = playlists;
	isLoading.value = false;
});

async function refreshPlaylistLibrary(event: RefresherCustomEvent): Promise<void> {
	isLoading.value = true;
	await musicPlayer.services.refreshLibraryPlaylists();
	const playlists: (Playlist | PlaylistPreview)[] = [];
	libraryPlaylists.value.length = 0;

	for await (const playlist of musicPlayer.services.libraryPlaylists()) {
		playlists.push(playlist);
	}
	playlists.push(...musicPlayer.state.getAllPlaylists());

	libraryPlaylists.value = playlists;
	isLoading.value = false;
	await event.target.complete();
}
</script>

<template>
	<AppPage title="Playlists" back-button="Library">
		<template #toolbar-end>
			<ion-buttons>
				<ion-button id="import-playlist">
					<ion-icon slot="icon-only" :icon="importIcon" />
				</ion-button>
				<ion-button id="add-playlist">
					<ion-icon slot="icon-only" :icon="addIcon" />
				</ion-button>
			</ion-buttons>
		</template>

		<ion-refresher slot="fixed" @ion-refresh="refreshPlaylistLibrary">
			<ion-refresher-content />
		</ion-refresher>

		<PlaylistImportModal trigger="import-playlist" />
		<PlaylistAddModal trigger="add-playlist" />

		<ion-list v-if="!libraryPlaylists.length && isLoading" id="playlists-list">
			<SkeletonItem v-for="i in 25" :key="i" />
		</ion-list>
		<ion-list id="playlists-list">
			<ion-item
				v-for="playlist in libraryPlaylists"
				:key="playlist.id"
				:router-link="`/items/playlists/${playlist.type}/${playlist.id}`"
			>
				<LocalImg
					size="large"
					slot="start"
					:src="playlist.artwork"
					:alt="`Artwork for playlist '${playlist.title}'`"
					:fallback-icon="playlistIcon"
				/>

				<ion-label class="ion-text-nowrap">
					<h2>{{ playlist.title }}</h2>
				</ion-label>
			</ion-item>
		</ion-list>
	</AppPage>
</template>

<style>
/**  TODO: Clean up CSS in playlist routes */

#playlists-list {
	background: transparent;
	& > ion-item {
		--background: transparent;
		min-height: 60px;

		& > .local-img {
			--img-height: 56px;
			border-radius: 8px;
			border: 0.55px solid #0002;
		}
	}
}
</style>
