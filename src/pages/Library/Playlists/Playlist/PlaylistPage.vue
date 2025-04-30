<script lang="ts" setup>
import { computed } from "vue";

import AppPage from "@/components/AppPage.vue";
import GenericSongItem from "@/components/GenericSongItem.vue";
import LocalImg from "@/components/LocalImg.vue";
import WrappingMarquee from "@/components/WrappingMarquee.vue";
import PlaylistEditModal, { PlaylistEditEvent } from "../components/PlaylistEditModal.vue";

import {
	ActionSheetButton,
	IonActionSheet,
	IonButton,
	IonButtons,
	IonHeader,
	IonIcon,
	IonItem,
	IonList,
	IonNote,
	IonTitle,
	IonToolbar,
	useIonRouter,
} from "@ionic/vue";
import {
	listOutline as addSongToQueueIcon,
	trashOutline as deleteIcon,
	pencil as editIcon,
	play as playIcon,
	playOutline as playSongNextIcon,
	shuffle as shuffleIcon,
} from "ionicons/icons";

import { filledPlaylist } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { useNavigation } from "@/stores/navigation";
import { useRoute } from "vue-router";

const musicPlayer = useMusicPlayer();
const navigation = useNavigation();
const router = useIonRouter();
const route = useRoute();

const playlist = computed(() => {
	const playlist = musicPlayer.state.getPlaylist(route.params.id as string);
	return playlist && filledPlaylist(playlist);
});
const isEmpty = computed(() => !playlist.value?.songs.length);
const totalDuration = computed(() => {
	const songs = playlist?.value?.songs ?? [];
	return songs.reduce((p, n) => p + (n.duration ?? 0), 0);
});

const deleteActionSheetButtons: ActionSheetButton[] = [
	{ text: "Delete", role: "destructive" },
	{ text: "Cancel", role: "cancel" },
];

function playPlaylist(shuffle = false): void {
	musicPlayer.state.setQueue(playlist.value!.songs.filter((song) => song.available));
	if (shuffle) {
		musicPlayer.state.shuffleQueue();
	}
	musicPlayer.state.queueIndex = 0;
}

function editPlaylist(event: PlaylistEditEvent): void {
	if (!playlist.value) return;
	playlist.value.title = event.title;
	playlist.value.artwork = event.artwork;
}

function onDeleteActionDismiss(event: CustomEvent): void {
	if (typeof event.detail !== "object" || !playlist.value) return;

	if (event.detail?.role === "destructive") {
		musicPlayer.state.removePlaylist(playlist.value.id);
		router.back();
	}
}
</script>

<template>
	<AppPage :title="playlist?.title" :show-content-header="false" back-button="Playlists">
		<template #toolbar-end>
			<ion-buttons>
				<ion-button id="edit-playlist">
					<ion-icon slot="icon-only" :icon="editIcon" />
				</ion-button>
				<ion-button id="delete-playlist">
					<ion-icon slot="icon-only" :icon="deleteIcon" />
				</ion-button>
			</ion-buttons>
		</template>

		<ion-action-sheet
			trigger="delete-playlist"
			:header="`Are you sure you want to delete playlist ${playlist?.title}?`"
			:buttons="deleteActionSheetButtons"
			@didDismiss="onDeleteActionDismiss"
		/>

		<PlaylistEditModal v-if="playlist" :playlist trigger="edit-playlist" @change="editPlaylist" />

		<div id="playlist-content" v-if="playlist">
			<LocalImg :src="playlist.artwork" />

			<ion-header collapse="condense">
				<ion-toolbar>
					<ion-title class="ion-text-nowrap" size="large">
						<WrappingMarquee :text="playlist.title" />
					</ion-title>
				</ion-toolbar>
			</ion-header>

			<ion-note v-if="isEmpty">This playlist has no songs, fill it up!</ion-note>
			<template v-else>
				<h2>{{ playlist.songs.length }} songs, {{ Math.round(totalDuration / 60) }} minutes</h2>

				<div class="buttons">
					<ion-button strong @click="playPlaylist(false)">
						<ion-icon slot="start" :icon="playIcon" />
						Play
					</ion-button>

					<ion-button strong @click="playPlaylist(true)">
						<ion-icon slot="start" :icon="shuffleIcon" />
						Shuffle
					</ion-button>
				</div>

				<ion-list>
					<GenericSongItem
						v-for="song in playlist.songs"
						:song
						:disabled="!song.available"
						:key="song.id"
						:title="song.title"
						:artists="song.artists"
						:artwork="song.artwork"
						:type="song.type"
						@item-click="musicPlayer.playSongNow(song)"
						@context-menu-click="navigation.goToSong(song)"
					>
						<template #options>
							<ion-item lines="full" button :detail="false" @click="musicPlayer.playSongNext(song)">
								Play Next
								<ion-icon aria-hidden="true" :icon="playSongNextIcon" slot="end" />
							</ion-item>
							<ion-item lines="full" button :detail="false" @click="musicPlayer.playSongLast(song)">
								Add to Queue
								<ion-icon aria-hidden="true" :icon="addSongToQueueIcon" slot="end" />
							</ion-item>
						</template>
					</GenericSongItem>
				</ion-list>
			</template>

			<!-- TODO: Maybe add a possibility to add songs from within this page -->
		</div>
	</AppPage>
</template>

<style>
#playlist-content {
	text-align: center;

	& > ion-header {
		width: max-content;
		max-width: 100%;
		margin-inline: auto;

		& .wrapping {
			mask-image: linear-gradient(to right, transparent, black 10% 90%, transparent);
		}

		& ion-title {
			transform-origin: top center;

			font-weight: bold;
			margin: 0;

			--marquee-duration: 20s;
			--marquee-align: center;
		}
	}

	& > h2 {
		font-size: 1rem;
		margin-top: 0;
	}

	& > .buttons {
		display: flex;
		width: 100%;
		align-items: center;
		justify-content: center;
		gap: 8px;

		padding-bottom: 1rem;
		border-bottom: 0.55px solid
			var(--ion-color-step-250, var(--ion-background-color-step-250, #c8c7cc));

		& > ion-button {
			width: calc(40%);
		}
	}

	& > .local-img {
		margin-inline: auto;

		--img-height: 192px;
		--img-width: auto;

		--shadow-color: rgba(var(--ion-color-dark-rgb), 0.1);

		border-radius: 12px;
		box-shadow: 0 0 12px var(--shadow-color);
		margin-block: 24px;
		background-color: rgba(var(--ion-color-dark-rgb), 0.08);

		& > .fallback {
			--size: 36px;
			filter: drop-shadow(0 0 12px var(--shadow-color));
		}
	}

	& > ion-list {
		width: 100%;
	}
}
</style>
