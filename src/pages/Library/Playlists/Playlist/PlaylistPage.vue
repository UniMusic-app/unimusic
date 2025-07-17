<script lang="ts" setup>
import { computed, reactive, ref } from "vue";
import { useRoute } from "vue-router";

import AppPage from "@/components/AppPage.vue";
import ContextMenu from "@/components/ContextMenu.vue";
import GenericSongItem from "@/components/GenericSongItem.vue";
import LocalImg from "@/components/LocalImg.vue";
import WrappingMarquee from "@/components/WrappingMarquee.vue";
import PlaylistEditModal from "../components/PlaylistEditModal.vue";

import {
	ActionSheetButton,
	IonActionSheet,
	IonButton,
	IonButtons,
	IonHeader,
	IonIcon,
	IonItem,
	IonItemDivider,
	IonList,
	IonNote,
	IonTitle,
	IonToolbar,
	useIonRouter,
} from "@ionic/vue";
import {
	listOutline as addSongToQueueIcon,
	swapHorizontalOutline as convertIcon,
	pieChartOutline as convertStatusIcon,
	trashOutline as deleteIcon,
	pencil as editIcon,
	ellipsisHorizontal as ellipsisIcon,
	play as playIcon,
	playOutline as playSongNextIcon,
	shuffle as shuffleIcon,
} from "ionicons/icons";

import { MusicService } from "@/services/Music/MusicService";
import {
	Filled,
	filledPlaylist,
	getCached,
	Playlist,
	PlaylistType,
} from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { useNavigation } from "@/stores/navigation";
import { Maybe } from "@/utils/types";
import { watchAsync } from "@/utils/vue";
import PlaylistConvertModal from "../components/PlaylistConvertModal.vue";
import PlaylistConvertStatusModal from "../components/PlaylistConvertStatusModal.vue";

const musicPlayer = useMusicPlayer();
const navigation = useNavigation();
const router = useIonRouter();
const route = useRoute();

const playlist = ref<Filled<Playlist>>();
const service = ref<MusicService>();

const supports = computed(() => {
	const isUniMusic = playlist.value?.type === "unimusic";
	const isMusicKit = playlist.value?.type === "musickit";

	return {
		edit: isUniMusic || !!service?.value?.handleModifyPlaylist,
		delete: isUniMusic || !!service?.value?.handleDeletePlaylist,
		convert: isMusicKit,
		convertStatus: isUniMusic && playlist.value?.data?.convert,
	};
});

const opened = reactive({
	edit: false,
	delete: false,
	convert: false,
	convertStatus: false,
});

const forceUpdate = ref(0);

watchAsync(
	() =>
		[
			route.params.playlistType as Maybe<PlaylistType>,
			route.params.playlistId as Maybe<string>,
			forceUpdate.value,
		] as const,
	async ([playlistType, playlistId]) => {
		if (!playlistType || !playlistId) return;

		service.value = undefined;

		if (playlistType === "unimusic") {
			const localPlaylist = musicPlayer.state.getPlaylist(playlistId);
			if (localPlaylist) {
				playlist.value = filledPlaylist(localPlaylist);
				return;
			}
		}

		const cachedPlaylist = getCached<Playlist>(playlistType, playlistId, "playlist");
		if (cachedPlaylist) {
			playlist.value = filledPlaylist(cachedPlaylist);
		}

		const libraryPlaylist = await musicPlayer.services.getPlaylist(playlistType, playlistId);
		if (libraryPlaylist) {
			service.value = musicPlayer.services.getService(playlistType);
			playlist.value = filledPlaylist(libraryPlaylist);
		}
	},
	{ immediate: true },
);

const isEmpty = computed(() => !playlist.value?.songs.length);
const totalDuration = computed(() => {
	const songs = playlist?.value?.songs ?? [];
	return songs.reduce((p, n) => p + (n.duration ?? 0), 0);
});

const deleteActionSheetButtons: ActionSheetButton[] = [
	{ text: "Delete", role: "destructive" },
	{ text: "Cancel", role: "cancel" },
];

async function playPlaylist(shuffle = false): Promise<void> {
	if (!playlist.value) return;

	const songs = await Promise.all(
		playlist.value.songs
			.filter((song) => song.available)
			.map((song) => musicPlayer.services.retrieveSong(song)),
	);

	musicPlayer.state.setQueue(songs);

	if (shuffle) {
		musicPlayer.state.shuffleQueue();
	}
	musicPlayer.state.queueIndex = 0;
}

function onDeleteActionDismiss(event: CustomEvent): void {
	if (typeof event.detail !== "object" || !playlist.value) return;

	if (event.detail?.role === "destructive") {
		router.back();
		musicPlayer.state.removePlaylist(playlist.value.id);
	}
}
</script>

<template>
	<AppPage :title="playlist?.title" :show-content-header="false">
		<template #toolbar-end>
			<ion-buttons>
				<ContextMenu
					v-if="supports.edit || supports.delete || supports.convert"
					event="click"
					:move="false"
					:backdrop="false"
					:haptics="false"
				>
					<ion-button>
						<ion-icon slot="icon-only" :icon="ellipsisIcon" />
					</ion-button>

					<template #options>
						<ion-item
							v-if="supports.edit"
							@click="opened.edit = !opened.edit"
							button
							aria-label="Edit playlist"
							lines="full"
							:detail="false"
						>
							Edit
							<ion-icon slot="end" :icon="editIcon" />
						</ion-item>

						<ion-item
							v-if="supports.delete"
							@click="opened.delete = !opened.delete"
							button
							aria-label="Delete playlist"
							lines="full"
							:detail="false"
						>
							Delete
							<ion-icon slot="end" :icon="deleteIcon" />
						</ion-item>

						<ion-item-divider
							v-if="(supports.edit || supports.delete) && (supports.convert || supports.convertStatus)"
						/>

						<ion-item
							v-if="supports.convert"
							@click="opened.convert = !opened.convert"
							button
							aria-label="Convert playlist"
							lines="full"
							:detail="false"
						>
							Convert playlist
							<ion-icon slot="end" :icon="convertIcon" />
						</ion-item>

						<ion-item
							v-if="supports.convertStatus"
							@click="opened.convertStatus = !opened.convertStatus"
							button
							aria-label="Convert status"
							lines="full"
							:detail="false"
						>
							Convert status
							<ion-icon slot="end" :icon="convertStatusIcon" />
						</ion-item>
					</template>
				</ContextMenu>
			</ion-buttons>
		</template>

		<ion-action-sheet
			v-if="playlist && opened.delete"
			:is-open="opened.delete"
			:header="`Are you sure you want to delete playlist ${playlist.title}?`"
			:buttons="deleteActionSheetButtons"
			@didDismiss="onDeleteActionDismiss"
		/>

		<PlaylistEditModal
			v-if="playlist && opened.edit"
			:playlist
			:service
			:is-open="opened.edit"
			@dismiss="opened.edit = false"
			@change="forceUpdate += 1"
		/>

		<PlaylistConvertModal
			v-if="playlist && opened.convert"
			:playlist
			:service
			:is-open="opened.convert"
			@dismiss="opened.convert = false"
			@change="forceUpdate += 1"
		/>

		<PlaylistConvertStatusModal
			v-if="playlist && opened.convertStatus"
			:playlist
			:is-open="opened.convertStatus"
			@dismiss="opened.convertStatus = false"
			@change="forceUpdate += 1"
		/>

		<div id="playlist-content" v-if="playlist">
			<LocalImg size="large" :src="playlist.artwork" />

			<ion-header collapse="condense">
				<ion-toolbar>
					<ion-title class="ion-text-nowrap" size="large">
						<WrappingMarquee :text="playlist.title" />
					</ion-title>
				</ion-toolbar>
			</ion-header>

			<ion-note v-if="isEmpty">This playlist has no songs, fill it up!</ion-note>
			<template v-else>
				<h2>
					{{ playlist.songs.length }} songs
					<template v-if="totalDuration">, {{ Math.round(totalDuration / 60) }} minutes</template>
				</h2>

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
