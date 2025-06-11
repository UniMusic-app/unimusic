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

import { PlaylistPreview, SongType } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";

const musicPlayer = useMusicPlayer();

const { item } = defineProps<{ item: Item }>();

const localPlaylists = shallowReactive<Playlist[]>([]);
const libraryPlaylists = useLocalStorage<(Playlist | PlaylistPreview)[]>("libraryPlaylists", []);
const servicePlaylists = shallowReactive<(Playlist | PlaylistPreview)[]>([]);
onMounted(async () => {
	for (const playlist of musicPlayer.state.getAllPlaylists()) {
		localPlaylists.push(playlist);
	}

	servicePlaylists.push(...libraryPlaylists.value.filter((playlist) => playlist.type === item.type));

	const service = musicPlayer.services.getService(item?.type);
	if (service?.handleGetLibraryPlaylists) {
		const playlists: (Playlist | PlaylistPreview)[] = [];
		for await (const playlist of service.getLibraryPlaylists()) {
			playlists.push(playlist);
		}
		servicePlaylists.length = 0;
		servicePlaylists.push(...playlists);
	}
});

async function addToPlaylist(playlist: Playlist | PlaylistPreview<SongType>): Promise<void> {
	await close();

	const songs: Song[] = [];

	switch (item.kind) {
		case "song":
		case "songPreview": {
			const song = await musicPlayer.services.retrieveSong(item);
			songs.push(song);
			break;
		}
		case "album":
		case "albumPreview": {
			const albumSongs = await musicPlayer.getAlbumSongs(item);
			songs.push(...albumSongs);
			break;
		}
	}

	if (playlist.type === "unimusic") {
		playlist.songs.push(...songs.map(getKey));
	} else {
		await musicPlayer.services.addSongsToPlaylist(
			playlist as Playlist<SongType> | PlaylistPreview<SongType>,
			songs,
		);
	}

	const positionAnchor =
		document.querySelector<HTMLElement>("#mini-music-player") ??
		document.querySelector<HTMLElement>("ion-tab-bar") ??
		undefined;
	const toast = await toastController.create({
		header: `Playlist "${playlist.title}"`,
		message: `${songs.length} ${songs.length > 1 ? "songs" : "song"} added`,
		icon: addIcon,

		duration: 2000,
		translucent: true,
		swipeGesture: "vertical",
		positionAnchor,
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
import { songTypeToDisplayName } from "@/utils/songs";
import { modalController } from "@ionic/vue";
import { useLocalStorage } from "@vueuse/core";

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
			<template v-if="localPlaylists.length">
				<ion-list-header>UniMusic playlists</ion-list-header>
				<ion-item
					class="playlist-item"
					v-for="playlist in localPlaylists"
					:key="playlist.id"
					@click="addToPlaylist(playlist)"
					button
					:detail="false"
				>
					<LocalImg :src="playlist.artwork" :fallback-icon="playlistIcon" slot="start" />
					<ion-label>{{ playlist.title }}</ion-label>
				</ion-item>
			</template>

			<TransitionGroup name="list">
				<template v-if="libraryPlaylists.length">
					<ion-list-header>{{ songTypeToDisplayName(item.type) }} playlists</ion-list-header>
					<ion-item
						class="playlist-item"
						v-for="playlist in servicePlaylists"
						:key="playlist.id"
						@click="addToPlaylist(playlist as Playlist<SongType> | PlaylistPreview<SongType>)"
						button
						:detail="false"
					>
						<LocalImg :src="playlist.artwork" :fallback-icon="playlistIcon" slot="start" />
						<ion-label>{{ playlist.title }}</ion-label>
					</ion-item>
				</template>
			</TransitionGroup>
		</ion-list>
	</ion-content>
</template>

<style>
.list-enter-active,
.list-leave-active {
	transition: all 250ms ease;
}

.list-enter-from,
.list-leave-to {
	opacity: 0;
}
</style>

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
