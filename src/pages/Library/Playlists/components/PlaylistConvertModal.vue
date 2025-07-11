<script lang="ts" setup>
import { computed, ref, shallowRef, useTemplateRef } from "vue";

import {
	arrowForward as arrowRightIcon,
	swapHorizontalOutline as convertIcon,
	checkmarkOutline as matchingIcon,
	closeCircleOutline as missingIcon,
	hourglassOutline as waitingIcon,
} from "ionicons/icons";

import { MusicService } from "@/services/Music/MusicService";
import {
	Filled,
	getKey,
	Identifiable,
	Playlist,
	Song,
	SongKey,
	SongPreview,
	SongType,
} from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import {
	actionSheetController,
	IonButton,
	IonButtons,
	IonContent,
	IonHeader,
	IonIcon,
	IonInput,
	IonItem,
	IonList,
	IonModal,
	IonSelect,
	IonSelectOption,
	IonSpinner,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";

import GenericSongItem from "@/components/GenericSongItem.vue";
import { useNavigation } from "@/stores/navigation";
import { generateUUID } from "@/utils/crypto";
import { songTypeToDisplayName } from "@/utils/songs";
import { stateSnapshot, usePresentingElement } from "@/utils/vue";

const musicPlayer = useMusicPlayer();
const navigation = useNavigation();

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
const canConvert = ref(false);
const canCreate = ref(false);
const playlistTitle = ref(playlist.title);

const targetServiceType = shallowRef<SongType>();
const supportedServices = computed(() =>
	musicPlayer.services.enabledServices.filter(
		(enabledService) =>
			enabledService.type !== playlistService?.type && enabledService.handleGetIsrcsFromSong,
	),
);

const converted = ref<
	Map<Song | SongPreview, Song | (SongPreview & Identifiable) | "matching" | "loading" | "missing">
>(new Map());

function dismiss(reason?: string): void {
	modal.value?.$el.dismiss(reason);
}

async function convert(): Promise<void> {
	if (!canConvert.value || !targetServiceType.value) return;

	const abortSignal = abortController.signal;

	loading.value = true;
	canCreate.value = false;

	const targetService = musicPlayer.services.getService(targetServiceType.value)!;

	converted.value = new Map();

	for (const song of playlist.songs) {
		converted.value.set(song, "loading");
	}

	for (const song of playlist.songs) {
		if (abortSignal.aborted) return;

		const service = playlistService ?? musicPlayer.services.getService(song.type);
		if (!service?.handleGetIsrcsFromSong || song.type === targetServiceType.value) {
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
	canCreate.value = true;
}

function reset(): void {
	abortController.abort();
	loading.value = false;
	targetServiceType.value = undefined;
	canConvert.value = false;
	canCreate.value = false;
	abortController = new AbortController();
}

function create(): void {
	if (!canConvert.value || !targetServiceType.value) return;

	const songs: SongKey[] = [];

	for (const song of playlist.songs) {
		let targetSong = converted.value.get(song);
		if (typeof targetSong !== "object") {
			targetSong = song;
		}

		songs.push(getKey(targetSong));
	}

	const convertedPlaylist: Playlist<"unimusic"> = {
		id: generateUUID(),
		kind: "playlist",
		type: "unimusic",

		title: playlistTitle.value,
		artwork: stateSnapshot(playlist.artwork),
		songs,

		data: {
			convert: { to: targetServiceType.value! },
		},
	};

	if (playlistService) {
		convertedPlaylist.data!.importInfo = {
			playlistId: playlist.id,
			service: playlistService?.type,
			sync: true,
		};
	}

	musicPlayer.state.addPlaylist(convertedPlaylist);

	navigation.goToPlaylist(convertedPlaylist);

	dismiss("convertedPlaylist");
}

async function canDismiss(reason?: "convertedPlaylist"): Promise<boolean> {
	if (reason === "convertedPlaylist" || !canConvert.value) return true;

	const actionSheet = await actionSheetController.create({
		header: `Playlist ${playlist.title}`,
		subHeader: "Are you sure you want to abort converting this playlist?",
		buttons: [
			{ text: "Discard", role: "destructive", data: { action: "discard" } },
			{ text: "Keep converting", role: "cancel", data: { action: "keep" } },
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
		@will-present="playlistTitle = playlist.title"
		@did-dismiss="(emit('dismiss'), reset())"
	>
		<ion-header>
			<ion-toolbar>
				<ion-buttons slot="start">
					<ion-button color="danger" @click="dismiss()">Cancel</ion-button>
				</ion-buttons>

				<ion-title>Convert Playlist</ion-title>

				<ion-buttons slot="end">
					<ion-button :disabled="!canCreate || loading" strong @click="create()">Create</ion-button>
				</ion-buttons>
			</ion-toolbar>
		</ion-header>

		<ion-content id="convert-playlist-content">
			<ion-list>
				<ion-item>
					<ion-input aria-label="Playlist Title" placeholder="Playlist Title" v-model="playlistTitle" />
				</ion-item>

				<ion-item>
					<ion-select
						label="Convert to"
						placeholder="Local"
						v-model="targetServiceType"
						@ion-change="canConvert = !!$event.target.value"
					>
						<ion-select-option
							v-for="service in supportedServices"
							:value="service.type"
							:key="service.type"
						>
							{{ songTypeToDisplayName(service.type) }}
						</ion-select-option>
					</ion-select>
				</ion-item>

				<ion-item lines="none">
					<ion-button :disabled="!canConvert" size="default" strong @click="convert">
						<template v-if="loading">
							<ion-spinner slot="start" />
							Loading...
						</template>
						<template v-else>
							<ion-icon slot="start" :icon="convertIcon" />
							Convert
						</template>
					</ion-button>
				</ion-item>
			</ion-list>

			<div id="playlist-preview" v-if="loading || canCreate">
				<h1>Preview</h1>

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
								description="Song is already using correct service"
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
#convert-playlist-content {
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

	& #playlist-preview {
		margin-top: 12px;
		padding: 0.5rem;
		border-radius: 12px 12px 0 0;
		background-color: var(--ion-color-light);
		animation: appear 750ms;
		text-align: center;
		min-height: calc(100% - 132px);

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
