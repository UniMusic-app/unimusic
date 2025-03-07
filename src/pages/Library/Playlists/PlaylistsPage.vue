<template>
	<ion-page>
		<AppHeader>
			<template #toolbar>
				<ion-buttons slot="start">
					<ion-back-button text="Library" />
				</ion-buttons>

				<ion-title>Playlists</ion-title>

				<ion-buttons slot="end">
					<!-- TODO: Better importing, for example we can access MusicKit playlists and show it to the user, also we can let user choose the platform instead of blindly guessing -->
					<ion-button id="import-playlist" @click="importPlaylist">
						<ion-icon slot="icon-only" :icon="importIcon" />
					</ion-button>
					<ion-button id="add-playlist">
						<ion-icon slot="icon-only" :icon="addIcon" />
					</ion-button>
				</ion-buttons>
			</template>
		</AppHeader>

		<!-- Modal for creating a new playlist -->
		<ion-modal
			ref="modal"
			trigger="add-playlist"
			:presenting-element="presentingElement"
			:can-dismiss="canDismiss"
		>
			<ion-header>
				<ion-toolbar>
					<ion-buttons slot="start">
						<ion-button color="danger" @click="dismiss()">Cancel</ion-button>
					</ion-buttons>

					<ion-title>Add Playlist</ion-title>

					<ion-buttons slot="end">
						<ion-button :disabled="!canCreate" strong @click="create()">Create</ion-button>
					</ion-buttons>
				</ion-toolbar>
			</ion-header>

			<ion-content id="playlist-add-modal-content" class="ion-padding">
				<SongImagePicker :id="playlistId" @input="artwork = $event.value" />

				<ion-list>
					<ion-item>
						<ion-input aria-label="Playlist Title" placeholder="Playlist Title" v-model="playlistTitle" />
					</ion-item>
				</ion-list>
			</ion-content>
		</ion-modal>

		<ion-content :fullscreen="true">
			<ion-list id="playlists-content">
				<ion-item
					v-for="playlist in musicPlayer.playlists"
					:key="playlist.id"
					:router-link="`/library/playlists/${playlist.id}`"
				>
					<!-- A nicer fallback if playlist has no artwork -->
					<ion-thumbnail slot="start">
						<SongImg :src="playlist.artwork" :alt="`Artwork for playlist '${playlist.title}'`" />
					</ion-thumbnail>

					<ion-label class="ion-text-nowrap">
						<h2>{{ playlist.title }}</h2>
					</ion-label>
				</ion-item>
			</ion-list>
		</ion-content>

		<AppFooter />
	</ion-page>
</template>

<script lang="ts" setup>
import { computed, ref, toRaw } from "vue";

import AppFooter from "@/components/AppFooter.vue";
import AppHeader from "@/components/AppHeader.vue";
import SongImagePicker from "@/components/SongImagePicker.vue";
import SongImg from "@/components/SongImg.vue";

import {
	actionSheetController,
	alertController,
	IonBackButton,
	IonButton,
	IonButtons,
	IonContent,
	IonHeader,
	IonIcon,
	IonInput,
	IonItem,
	IonLabel,
	IonList,
	IonModal,
	IonPage,
	IonThumbnail,
	IonTitle,
	IonToolbar,
	loadingController,
} from "@ionic/vue";
import { add as addIcon, downloadOutline as importIcon } from "ionicons/icons";

import { SongImage, useMusicPlayer } from "@/stores/music-player";

import { MusicPlayerService } from "@/services/MusicPlayer/MusicPlayerService";
import { generateUUID } from "@/utils/crypto";
import { usePresentingElement } from "@/utils/vue";

const musicPlayer = useMusicPlayer();

const presentingElement = usePresentingElement();
const modal = ref<typeof IonModal>();

const playlistId = ref(generateUUID());
const playlistTitle = ref("");
const artwork = ref<SongImage>();
const modified = computed(() => !!(playlistTitle.value || artwork.value));
const canCreate = computed(() => !!playlistTitle.value);

function resetModal(): void {
	playlistId.value = generateUUID();
	playlistTitle.value = "";
	artwork.value = undefined;
}

function dismiss(): void {
	modal.value?.$el.dismiss();
}

async function importPlaylist(): Promise<void> {
	const alert = await alertController.create({
		header: "Import Playlist",
		message: "Enter URL of the playlist you want to import",
		inputs: [{ type: "url", placeholder: "Playlist URL" }],
		buttons: [
			{ text: "Cancel", role: "cancel" },
			{ text: "Import", role: "selected" },
		],
	});

	await alert.present();

	const { data, role } = await alert.onDidDismiss();
	if (role !== "selected") {
		return;
	}

	const loading = await loadingController.create({
		message: "Importing your playlist...",
	});

	await loading.present();

	try {
		const url = new URL(data.values[0]);

		for (const service of MusicPlayerService.getEnabledServices()) {
			console.log(service.type);
			const playlist = await service.getPlaylist(url);

			if (playlist) {
				musicPlayer.addPlaylist(playlist);
				await loading.dismiss();
				return;
			}
		}

		await loading.dismiss();
	} catch (error) {
		console.error(error);
		await loading.dismiss();
	}

	const missingAlert = await alertController.create({
		header: "Playlist Import Failed",
		message:
			"Importing your playlist failed. Make sure the URL is a valid playlist and you have the proper service enabled.",
		buttons: ["Dismiss"],
	});
	await missingAlert.present();
}

function create(): void {
	if (!playlistTitle.value) return;

	musicPlayer.addPlaylist({
		id: playlistId.value,
		title: playlistTitle.value,
		artwork: toRaw(artwork.value),
		songs: [],
	});

	resetModal();
	modal.value?.$el.dismiss("createdPlaylist");
}

async function canDismiss(reason?: "createdPlaylist"): Promise<boolean> {
	if (reason === "createdPlaylist" || !modified.value) return true;

	const actionSheet = await actionSheetController.create({
		header: `Playlist ${playlistTitle.value}`,
		subHeader: "Are you sure you want to discard this new playlist?",
		buttons: [
			{ text: "Discard", role: "destructive", data: { action: "discard" } },
			{ text: "Keep editing", role: "cancel", data: { action: "keep" } },
		],
	});

	await actionSheet.present();
	const info = await actionSheet.onWillDismiss();

	switch (info?.data?.action) {
		case "discard":
			resetModal();
			return true;
		default:
			return false;
	}
}
</script>

<style>
#playlists-content {
	background: transparent;
	& > ion-item {
		--background: transparent;
		min-height: 60px;

		& > ion-thumbnail > .song-img {
			border-radius: 8px;
		}
	}
}

#playlist-add-modal-content {
	& > ion-list {
		background: transparent;
		& > ion-item {
			--background: transparent;

			& > ion-input {
				font-weight: 600;
				font-size: 1.25rem;
				text-align: center;
			}
		}
	}
}
</style>
