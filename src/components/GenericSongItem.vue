<script lang="ts" setup>
import { computed, ref } from "vue";

import LocalImg from "@/components/LocalImg.vue";
import { IonIcon, IonItem, IonItemDivider, IonLabel, IonNote, IonReorder } from "@ionic/vue";
import {
	addOutline as addIcon,
	compassOutline as compassIcon,
	hourglassOutline as hourglassIcon,
	musicalNoteOutline as musicalNoteIcon,
	playOutline as playIcon,
	listCircleOutline as playlistAddIcon,
	musicalNotesOutline as songIcon,
} from "ionicons/icons";

import ContextMenu from "@/components/ContextMenu.vue";
import { filledDisplayableArtist, Song, SongPreview } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { formatArtists, kindToDisplayName, songTypeToDisplayName } from "@/utils/songs";
import { secondsToMMSS } from "@/utils/time";

import { openAddToPlaylistModal } from "@/pages/Library/Playlists/components/AddToPlaylistModal.vue";

const {
	button = true,
	title,
	type,
	kind,
	artists,
	album,
	artwork,
	duration,
	reorder,
	disabled,
	routerLink,
	song,
} = defineProps<
	Pick<Partial<Song>, "type" | "duration" | "album" | "artists" | "artwork" | "title"> & {
		kind?: "song" | "songPreview";
		reorder?: boolean;
		button?: boolean;
		disabled?: boolean;
		routerLink?: string;
		song?: Song | SongPreview;
	}
>();

const musicPlayer = useMusicPlayer();

const formattedArtists = computed(
	() => artists && formatArtists(artists?.map(filledDisplayableArtist)),
);
const displayName = computed(() => type && songTypeToDisplayName(type));
const formattedDuration = computed(() => duration && secondsToMMSS(duration));

const emit = defineEmits<{
	itemClick: [PointerEvent];
	contextMenuClick: [PointerEvent];
	visibilitychange: [value: boolean];
}>();

const contextMenuOpen = ref(false);

function emitClick(event: PointerEvent): void {
	if (contextMenuOpen.value) {
		emit("contextMenuClick", event);
	} else {
		emit("itemClick", event);
	}
}
</script>

<template>
	<ContextMenu
		:class="$props.class"
		ref="contextMenu"
		@visibilitychange="contextMenuOpen = $event"
		position="top"
	>
		<ion-item
			:router-link
			:button
			:disabled
			:detail="contextMenuOpen"
			@click="emitClick"
			class="song-item"
			:class="$attrs.class"
		>
			<LocalImg
				slot="start"
				:src="artwork"
				:alt="`Artwork for song '${title}' by ${formattedArtists}`"
				:fallback-icon="songIcon"
			/>

			<ion-label>
				<h1>{{ title ?? "Unknown title" }}</h1>
				<ion-note class="ion-text-nowrap">
					<p v-if="kind">
						<ion-icon :icon="songIcon" />
						{{ kindToDisplayName(kind) }}
					</p>
					<template v-if="artists && type">
						<p>
							<ion-icon :icon="compassIcon" />
							{{ displayName }}
						</p>
						<p>
							<ion-icon :icon="musicalNoteIcon" />
							{{ formattedArtists }}
						</p>
					</template>
					<template v-else-if="album">
						<p>{{ album }}</p>
					</template>
					<template v-else-if="duration">
						<p>{{ formattedDuration }}</p>
					</template>
				</ion-note>
			</ion-label>

			<ion-reorder v-if="reorder" slot="end" />
		</ion-item>

		<template #options>
			<slot name="options">
				<template v-if="song">
					<ion-item :button="true" :detail="false" @click="musicPlayer.playSongNow(song)">
						<ion-icon aria-hidden="true" :icon="playIcon" slot="end" />
						Play now
					</ion-item>

					<ion-item :button="true" :detail="false" @click="musicPlayer.playSongNext(song)">
						<ion-icon aria-hidden="true" :icon="hourglassIcon" slot="end" />
						Play next
					</ion-item>

					<ion-item :button="true" :detail="false" @click="musicPlayer.playSongLast(song)">
						<ion-icon aria-hidden="true" :icon="addIcon" slot="end" />
						Add to queue
					</ion-item>

					<ion-item-divider />

					<ion-item
						data-instant-close
						:button="true"
						:detail="false"
						@click="openAddToPlaylistModal(song)"
					>
						<ion-icon aria-hidden="true" :icon="playlistAddIcon" slot="end" />
						Add to playlist
					</ion-item>
				</template>
			</slot>
		</template>
	</ContextMenu>
</template>

<style scoped>
.context-menu {
	:global(&:has(.song-item)) {
		--move-item-height: 8.65rem;
	}

	&.opened .song-item {
		--background: var(--ion-background-color-step-100, #fff);

		border-radius: 24px;
		--border-color: transparent;

		--padding-top: 12px;
		--padding-bottom: 12px;
		--padding-start: 12px;
		--padding-end: 12px;

		& > .local-img {
			--img-height: 6.75rem;
			border-radius: 12px;
		}

		& > ion-label {
			height: max-content;
			white-space: normal;

			& > h1 {
				font-size: 1.2rem;
				line-height: 1;

				@supports (not (line-clamp: 2)) and (not (-webkit-line-clamp: 2)) {
					max-height: 2em;
					overflow: hidden;
					text-overflow: ellipsis;
				}

				@supports (line-clamp: 2) {
					line-clamp: 2;
				}

				@supports (-webkit-line-clamp: 2) {
					overflow: hidden;
					display: -webkit-box;
					-webkit-line-clamp: 2;
					-webkit-box-orient: vertical;
				}
			}

			& > ion-note {
				margin-top: 0.5rem;
				flex-direction: column;
				align-items: start;

				& > p {
					line-height: 1;
					align-items: start;
					font-size: 0.85rem;
				}
			}
		}

		& > ion-reorder {
			display: none;
		}
	}
}

.song-item {
	& > .local-img {
		pointer-events: none;

		--img-width: auto;
		--img-height: 56px;

		border-radius: 8px;
		border: 0.55px solid #0002;
	}

	& > ion-label {
		pointer-events: none;
		white-space: nowrap;

		overflow: hidden;
		white-space: nowrap;
		text-overflow: ellipsis;

		& > h1 {
			font-size: 0.9em;
			font-weight: 550;
			display: block;
		}

		& > ion-note {
			display: inline-flex;
			gap: 0.5ch;
			align-items: center;
			font-size: 0.75em;

			& > p {
				display: flex;
				align-items: center;
				gap: 4px;
				font-size: inherit;

				& > ion-icon {
					min-width: 1em;
				}
			}
		}
	}

	& > ion-reorder {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
	}
}
</style>
