<script lang="ts" setup>
import { computed, ref, useTemplateRef } from "vue";

import {
	arrowForward as arrowRightIcon,
	swapHorizontalOutline as convertIcon,
	checkmarkOutline as matchingIcon,
	closeCircleOutline as missingIcon,
	refreshOutline as updateIcon,
	hourglassOutline as waitingIcon,
} from "ionicons/icons";

import { MusicService } from "@/services/Music/MusicService";
import {
	Filled,
	filledPlaylist,
	getCachedFromKey,
	getKey,
	Identifiable,
	Playlist,
	Song,
	SongKey,
	SongPreview,
} from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import {
	actionSheetController,
	IonButton,
	IonButtons,
	IonContent,
	IonHeader,
	IonIcon,
	IonItem,
	IonList,
	IonModal,
	IonSpinner,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";

import GenericSongItem from "@/components/GenericSongItem.vue";
import { useNavigation } from "@/stores/navigation";
import { usePresentingElement } from "@/utils/vue";

const musicPlayer = useMusicPlayer();

const emit = defineEmits<{ change: []; dismiss: [] }>();

const {
	isOpen,
	service: playlistService,
	playlist,
} = defineProps<{
	isOpen: boolean;
	service?: MusicService;
	playlist: Filled<Playlist>;
}>();

const modal = useTemplateRef("modal");
const presentingElement = usePresentingElement();

let abortController = new AbortController();
const loading = ref(false);
const canUpdate = ref(true);
const canApply = ref(false);

const targetServiceType = computed(() => playlist.data?.convert?.to);

const converted = ref<
	Map<Song | SongPreview, Song | (SongPreview & Identifiable) | "matching" | "loading" | "missing">
>(new Map());

function dismiss(reason?: string): void {
	modal.value?.$el.dismiss(reason);
}

async function load(): Promise<void> {
	converted.value = new Map();
	for (const song of playlist.songs) {
		converted.value.set(song, song.type === targetServiceType.value ? "matching" : "missing");
	}
}

async function update(): Promise<void> {
	if (!canUpdate.value || !targetServiceType.value) return;

	const abortSignal = abortController.signal;

	loading.value = true;
	canApply.value = false;
	canUpdate.value = false;

	const importInfo = playlist.data?.importInfo;
	if (importInfo) {
		const { playlistId, service, sync } = importInfo;
		const sourceService = musicPlayer.services.getService(service);

		if (!sourceService) {
			console.error(`Failed to get service: ${service}, cannot sync playlist.`);
		} else if (sync) {
			const latestPlaylist = await sourceService.getPlaylist(playlistId);
			if (!latestPlaylist) {
				console.error(`Failed to fetch playlist ${playlistId}, cannot sync.`);
			} else {
				const filledLatestPlaylist = filledPlaylist(latestPlaylist);
				playlist.songs = filledLatestPlaylist.songs;
			}
		}
	}

	const targetService = musicPlayer.services.getService(targetServiceType.value)!;

	converted.value = new Map();

	for (const song of playlist.songs) {
		converted.value.set(song, "loading");
	}

	for (const song of playlist.songs) {
		if (abortSignal.aborted) return;

		const service = playlistService ?? musicPlayer.services.getService(song.type);
		if (!service?.handleGetIsrcsFromSong) {
			continue;
		}

		if (song.type === targetServiceType.value) {
			converted.value.set(song, "matching");
			continue;
		}

		const isrcs = await service.getIsrcsFromSong(song);
		const targetSong = await targetService.getSongFromIsrcs(isrcs);
		converted.value.set(song, targetSong ?? "missing");
	}

	loading.value = false;
	canApply.value = true;
	canUpdate.value = true;
}

function reset(): void {
	abortController.abort();
	loading.value = false;
	canUpdate.value = true;
	canApply.value = false;
	abortController = new AbortController();
}

function apply(): void {
	if (!canUpdate.value || !targetServiceType.value) return;

	const songs: SongKey[] = [];

	for (const song of playlist.songs) {
		let targetSong = converted.value.get(song);
		if (typeof targetSong !== "object") {
			targetSong = song;
		}

		songs.push(getKey(targetSong));
	}

	const localPlaylist = musicPlayer.state.getPlaylist(playlist.id)!;
	localPlaylist.songs = songs;

	playlist.songs = songs.map((song) => {
		const cached = getCachedFromKey(song);
		if (!cached) {
			throw new Error(`Tried to retrieve song ${song}, but it is not cached`);
		}
		return cached;
	});

	dismiss("updatedPlaylist");
}

async function canDismiss(reason?: "updatedPlaylist"): Promise<boolean> {
	if (reason === "updatedPlaylist" || !canUpdate.value) return true;

	const actionSheet = await actionSheetController.create({
		header: `Playlist ${playlist.title}`,
		subHeader: "Are you sure you want to abort updating this playlist?",
		buttons: [
			{ text: "Discard", role: "destructive", data: { action: "discard" } },
			{ text: "Keep updating", role: "cancel", data: { action: "keep" } },
		],
	});

	await actionSheet.present();
	const info = await actionSheet.onWillDismiss();

	switch (info?.data?.action) {
		case "discard":
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
		@will-present="load"
		@did-dismiss="(emit('dismiss'), reset())"
	>
		<ion-header>
			<ion-toolbar>
				<ion-buttons slot="start">
					<ion-button color="danger" @click="dismiss()">Cancel</ion-button>
				</ion-buttons>

				<ion-title>Convert Status</ion-title>

				<ion-buttons slot="end">
					<ion-button :disabled="!canApply" strong @click="apply()">Apply</ion-button>
				</ion-buttons>
			</ion-toolbar>
		</ion-header>

		<ion-content id="convert-status-playlist-content">
			<ion-list>
				<ion-item lines="none">
					<ion-button :disabled="!canUpdate || loading" size="default" strong @click="update">
						<template v-if="loading">
							<ion-spinner slot="start" />
							Loading...
						</template>
						<template v-else>
							<ion-icon slot="start" :icon="updateIcon" />
							Update
						</template>
					</ion-button>
				</ion-item>
			</ion-list>

			<div id="playlist-convert-status">
				<h1>Status</h1>

				<!-- TODO: Allow declining and manually choosing replacement -->
				<ion-list>
					<ion-item lines="full" v-for="[before, after] in converted" :key="before.id">
						<div class="comparison">
							<GenericSongItem
								disabled-context-menu
								:button="false"
								lines="none"
								:title="before.title"
								:artists="before.artists"
								:artwork="before.artwork"
								:type="before.type"
							/>

							<ion-icon :icon="arrowRightIcon" />

							<GenericSongItem
								v-if="typeof after === 'object'"
								disabled-context-menu
								:button="false"
								lines="none"
								:title="after.title"
								:artists="after.artists"
								:artwork="after.artwork"
								:type="after.type"
							/>
							<GenericSongItem
								v-else-if="after === 'loading'"
								disabled-context-menu
								:button="false"
								lines="none"
								title="Waiting"
								description="Queued for migration"
								:artwork="{ style: { bgColor: '#9090ff' } }"
								:fallback-icon="waitingIcon"
							/>
							<GenericSongItem
								v-else-if="after === 'missing'"
								disabled-context-menu
								:button="false"
								lines="none"
								title="Missing"
								description="Failed to find equivalent song"
								:artwork="{ style: { bgColor: '#ff9090' } }"
								:fallback-icon="missingIcon"
							/>
							<GenericSongItem
								v-else
								disabled-context-menu
								:button="false"
								lines="none"
								title="Matched"
								description="Song is using target service"
								:artwork="{ style: { bgColor: '#90ff90' } }"
								:fallback-icon="matchingIcon"
							/>
						</div>
					</ion-item>
				</ion-list>
			</div>
		</ion-content>
	</ion-modal>
</template>

<style scoped>
#convert-status-playlist-content {
	text-align: center;
	display: flex;
	flex-direction: column;
	justify-content: center;
	align-items: center;

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

			& > ion-button {
				width: 100%;
				padding-top: 1rem;

				& > ion-spinner {
					margin-right: 0.5rem;
					width: 1em;
					height: 1em;
				}
			}
		}
	}

	& #playlist-convert-status {
		margin-top: 12px;
		padding: 0.5rem;
		border-radius: 12px 12px 0 0;
		background-color: var(--ion-color-light);
		animation: appear 750ms;
		text-align: center;
		min-height: calc(100% - 90px);

		& > h1 {
			font-size: 2.25rem;
			padding-bottom: 0.5rem;
			color: var(--ion-color-medium);
		}

		& > ion-list {
			background: transparent;

			& > ion-item {
				--background: transparent;
				--padding-start: 0px;
				--padding-end: 0px;
				--inner-padding-start: 0px;
				--inner-padding-end: 0px;

				& > .comparison {
					display: grid;
					grid-template-columns: minmax(calc(50% - 1.5rem), 1fr) 3rem minmax(calc(50% - 1.5rem), 1fr);
					grid-template-rows: 1fr;

					width: 100%;
					align-items: center;
					justify-content: center;
				}

				& ion-icon {
					width: 100%;
					height: 1.25rem;
				}

				& > .missing-text {
					width: 100%;
				}

				:deep(& .context-menu-item) {
					width: 100%;
				}

				:deep(& .song-item) {
					--background: var(--ion-color-light);
				}
			}
		}
	}
}

@keyframes appear {
	from {
		transform: scale(80%) translateY(100px);
		opacity: 0;
	}

	to {
		transform: scale(100%) translateY(0px);
		opacity: 1;
	}
}
</style>
