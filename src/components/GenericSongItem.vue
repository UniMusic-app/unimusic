<script lang="ts" setup>
import { computed, ref } from "vue";

import ContextMenu from "@/components/ContextMenu.vue";
import SongImg from "@/components/SongImg.vue";
import { IonIcon, IonItem, IonLabel, IonNote } from "@ionic/vue";
import { compass as compassIcon, musicalNote as musicalNoteIcon } from "ionicons/icons";

import { AnySong, SongImage } from "@/stores/music-player";
import { formatArtists, songTypeToDisplayName } from "@/utils/songs";

const { title, type, artists, artwork } = defineProps<{
	title?: string;
	type: AnySong["type"];
	artists: string[];
	artwork?: SongImage;
}>();

const formattedArtists = computed(() => formatArtists(artists));
const displayName = computed(() => songTypeToDisplayName(type));

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
	<ContextMenu @visibilitychange="contextMenuOpen = $event">
		<ion-item button :detail="contextMenuOpen" @click="emitClick">
			<SongImg
				v-if="artwork"
				slot="start"
				:src="artwork"
				:alt="`Artwork for song '${title}' by ${formattedArtists}`"
			/>

			<ion-label>
				<h2>{{ title ?? "Unknown title" }}</h2>
				<ion-note>
					<p>
						<ion-icon :icon="compassIcon" />
						{{ displayName }}
					</p>
					<p>
						<ion-icon :icon="musicalNoteIcon" />
						{{ formattedArtists }}
					</p>
				</ion-note>
			</ion-label>
		</ion-item>

		<template #options>
			<slot name="options" />
		</template>
	</ContextMenu>
</template>

<style scoped>
.context-menu:not(.closed) > .context-menu-item > ion-item {
	transition: var(--context-menu-transition);

	--background: var(--context-menu-item-background);

	--border-radius: 16px;
	--border-color: transparent;
	--padding-top: 16px;
	--padding-bottom: 16px;

	&::part(native) {
		display: flex;
		flex-wrap: wrap;
	}

	& > .song-img {
		transition: var(--context-menu-transition);

		--img-border-radius: 12px;
		--img-width: 96px;
		--img-height: auto;
	}

	& > ion-label {
		height: max-content;
		white-space: normal;

		& > h2 {
			font-size: 1.2rem;
			line-height: 1;

			@supports (line-clamp: 2) {
				line-clamp: 2;
			}

			@supports not (line-clamp: 2) {
				max-height: 2em;
				overflow: hidden;
				text-overflow: ellipsis;
			}
		}

		& > ion-note {
			margin-top: 1em;
			flex-direction: column;
			align-items: start;

			& > p {
				align-items: start;
				font-size: 1.1em;
			}
		}
	}
}

ion-item {
	& > .song-img {
		pointer-events: none;

		--img-border-radius: 8px;
		--img-width: auto;
		--img-height: 56px;
	}

	& > ion-label {
		pointer-events: none;
		white-space: nowrap;

		& > h2 {
			font-size: 1rem;
			font-weight: bold;
			display: block;
		}

		& > ion-note {
			display: flex;
			gap: 0.5ch;
			font-size: 0.8em;
			align-items: center;

			& > p {
				display: flex;
				align-items: center;
				gap: 4px;

				& > ion-icon {
					min-width: 1em;
				}
			}
		}
	}
}
</style>
