<script lang="ts" setup>
import { computed, ref, useTemplateRef } from "vue";

import LocalImagePicker from "@/components/LocalImagePicker.vue";
import { MusicService, PlaylistModifications } from "@/services/Music/MusicService";
import { Filled, Playlist } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import {
	actionSheetController,
	IonButton,
	IonButtons,
	IonContent,
	IonHeader,
	IonInput,
	IonItem,
	IonList,
	IonModal,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";

import { stateSnapshot, usePresentingElement } from "@/utils/vue";

const musicPlayer = useMusicPlayer();

const emit = defineEmits<{ change: []; dismiss: [] }>();

const { isOpen, service, playlist } = defineProps<{
	isOpen: boolean;
	service?: MusicService;
	playlist: Filled<Playlist>;
}>();

const modal = useTemplateRef("modal");
const presentingElement = usePresentingElement();

const playlistTitle = ref(playlist.title);
const artwork = ref(playlist.artwork);
const modified = ref(false);
const canEdit = computed(() => !!playlistTitle.value && modified.value);

async function edit(): Promise<void> {
	if (!canEdit.value) return;

	const modifications: PlaylistModifications = {};

	if (artwork.value !== playlist.artwork) {
		modifications.artwork = stateSnapshot(artwork.value);
	}

	if (playlistTitle.value !== playlist.title) {
		modifications.title = playlistTitle.value;
	}

	if (service) {
		await service.modifyPlaylist(playlist.id, modifications);
	} else {
		Object.assign(musicPlayer.state.playlists[playlist.id]!, modifications);
		emit("change");
	}

	dismiss("editedPlaylist");
}

function dismiss(reason?: string): void {
	modal.value?.$el.dismiss(reason);
}

async function canDismiss(reason?: "editedPlaylist"): Promise<boolean> {
	if (reason === "editedPlaylist" || !modified.value) return true;

	const actionSheet = await actionSheetController.create({
		header: `Playlist ${playlistTitle.value}`,
		subHeader: "Are you sure you want to discard changes made to this playlist?",
		buttons: [
			{ text: "Discard", role: "destructive", data: { action: "discard" } },
			{ text: "Keep editing", role: "cancel", data: { action: "keep" } },
		],
	});

	await actionSheet.present();
	const info = await actionSheet.onWillDismiss();

	switch (info?.data?.action) {
		case "discard":
			playlistTitle.value = playlist.title;
			return true;
		default:
			return false;
	}
}
</script>

<template>
	<ion-modal
		ref="modal"
		:is-open
		:presenting-element="presentingElement"
		:can-dismiss="canDismiss"
		@will-present="playlistTitle = playlist.title"
		@did-dismiss="emit('dismiss')"
	>
		<ion-header>
			<ion-toolbar>
				<ion-buttons slot="start">
					<ion-button color="danger" @click="dismiss()">Cancel</ion-button>
				</ion-buttons>

				<ion-title>Edit Playlist</ion-title>

				<ion-buttons slot="end">
					<ion-button :disabled="!canEdit" strong @click="edit()">Edit</ion-button>
				</ion-buttons>
			</ion-toolbar>
		</ion-header>

		<ion-content id="edit-playlist-content" :fullscreen="true">
			<LocalImagePicker :id="playlist.id" @input="((artwork = $event.value), (modified = true))" />

			<ion-list>
				<ion-item>
					<ion-input
						aria-label="Playlist Title"
						placeholder="Playlist Title"
						v-model="playlistTitle"
						@ion-change="modified = true"
					/>
				</ion-item>
			</ion-list>
		</ion-content>
	</ion-modal>
</template>

<style scoped>
#edit-playlist-content {
	text-align: center;

	& > h1 {
		font-weight: bold;
		margin-bottom: 0.25rem;
	}

	& > h2 {
		font-size: 1rem;
		margin-top: 0;
	}

	& > ion-button {
		&::part(native) {
			width: 33%;
			margin-inline: auto;
		}

		width: 100%;
		padding-bottom: 1rem;
		border-bottom: 0.55px solid
			var(--ion-color-step-250, var(--ion-background-color-step-250, #c8c7cc));
	}

	& > ion-list {
		width: 100%;
		background: transparent;

		& > ion-item {
			--background: transparent;

			& > ion-input {
				font-size: 1.625rem;
				font-weight: bold;
				text-align: center;
			}
		}
	}
}
</style>
