<script lang="ts" setup>
import { onMounted, shallowReactive } from "vue";

import LocalImg from "@/components/LocalImg.vue";
import {
	IonButton,
	IonButtons,
	IonContent,
	IonHeader,
	IonItem,
	IonLabel,
	IonList,
	IonListHeader,
	IonTitle,
	IonToolbar,
	toastController,
} from "@ionic/vue";
import { addOutline as addIcon, listOutline as playlistIcon } from "ionicons/icons";

import { SongKey } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";

const musicPlayer = useMusicPlayer();

const { item } = defineProps<{ item: Item }>();

const playlists = shallowReactive<Playlist[]>([]);
onMounted(() => {
	for (const playlist of musicPlayer.state.getAllPlaylists()) {
		playlists.push(playlist);
	}
});

async function addToPlaylist(playlist: Playlist): Promise<void> {
	await close();

	const songs: SongKey[] = [];

	switch (item.kind) {
		case "song":
		case "songPreview": {
			const song = await musicPlayer.services.retrieveSong(item);
			songs.push(getKey(song));
			break;
		}
		case "album":
		case "albumPreview": {
			const albumSongs = await musicPlayer.getAlbumSongs(item);
			songs.push(...albumSongs.map(getKey));
			break;
		}
	}

	playlist.songs.push(...songs);

	const toast = await toastController.create({
		header: `Playlist "${playlist.title}"`,
		message: `${songs.length} ${songs.length > 1 ? "songs" : "song"} added`,
		icon: addIcon,

		duration: 2000,
		translucent: true,
		swipeGesture: "vertical",
		positionAnchor: "mini-music-player",
	});
	await toast.present();
}

async function close(): Promise<void> {
	await modalController.dismiss();
}
</script>

<script lang="ts">
import AddToPlaylistModal from "./AddToPlaylistModal.vue";

import { Album, AlbumPreview, getKey, Playlist, Song, SongPreview } from "@/services/Music/objects";
import { modalController } from "@ionic/vue";

type Item = Song | SongPreview | Album | AlbumPreview;

export async function createAddToPlaylistModal(item: Item): Promise<HTMLIonModalElement> {
	const modal = await modalController.create({
		component: AddToPlaylistModal,
		presentingElement: document.querySelector("ion-router-outlet") ?? undefined,
		componentProps: { item },
	});
	return modal;
}

export async function openAddToPlaylistModal(item: Item): Promise<void> {
	const modal = await createAddToPlaylistModal(item);
	await modal.present();
	await modal.onDidDismiss();
}
</script>

<template>
	<ion-header>
		<ion-toolbar>
			<ion-buttons slot="start">
				<ion-button :strong="true" @click="close">Cancel</ion-button>
			</ion-buttons>

			<ion-title>Add to Playlist</ion-title>
		</ion-toolbar>
	</ion-header>
	<ion-content>
		<ion-list>
			<ion-list-header>All playlists</ion-list-header>

			<ion-item
				class="playlist-item"
				v-for="playlist in playlists"
				:key="playlist?.id"
				@click="addToPlaylist(playlist)"
				button
				:detail="false"
			>
				<LocalImg :src="playlist.artwork" :fallback-icon="playlistIcon" slot="start" />
				<ion-label>{{ playlist.title }}</ion-label>
			</ion-item>
		</ion-list>
	</ion-content>
</template>

<style scoped>
ion-list-header {
	margin-bottom: 8px;
}

.playlist-item {
	& > .local-img {
		pointer-events: none;

		--img-width: auto;
		--img-height: 56px;

		border-radius: 8px;
		border: 0.55px solid #0002;
	}
}
</style>
