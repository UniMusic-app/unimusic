<script lang="ts" setup>
import { computed, ref } from "vue";

import ContextMenu from "@/components/ContextMenu.vue";
import SongImg from "@/components/SongImg.vue";
import { IonIcon, IonItem, IonLabel, IonNote, IonReorder } from "@ionic/vue";
import { compass as compassIcon, musicalNote as musicalNoteIcon } from "ionicons/icons";

import { AnySong, SongImage } from "@/stores/music-player";
import { formatArtists, songTypeToDisplayName } from "@/utils/songs";

const { title, type, artists, artwork, reorder } = defineProps<{
	title?: string;
	type: AnySong["type"];
	artists: string[];
	artwork?: SongImage;
	reorder?: boolean;
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
	<ContextMenu :class="$props.class" ref="contextMenu" @visibilitychange="contextMenuOpen = $event">
		<ion-item button :detail="contextMenuOpen" @click="emitClick" :class="$attrs.class">
			<SongImg
				v-if="artwork"
				slot="start"
				:src="artwork"
				:alt="`Artwork for song '${title}' by ${formattedArtists}`"
			/>

			<ion-label>
				<h1>{{ title ?? "Unknown title" }}</h1>
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

			<ion-reorder data-context-menu-ignore v-if="reorder" slot="end" />
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

	border-radius: 24px;
	--border-color: transparent;

	--padding-top: 12px;
	--padding-bottom: 12px;
	--padding-start: 12px;
	--padding-end: 12px;

	& > .song-img {
		transition: var(--context-menu-transition);

		--img-border-radius: 12px;
		--img-width: 96px;
		--img-height: auto;
	}

	& > ion-label {
		height: max-content;
		white-space: normal;

		& > h1 {
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

	& > ion-reorder {
		display: none;
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

		& > h1 {
			font-size: 0.9em;
			font-weight: 550;
			display: block;
		}

		& > ion-note {
			display: flex;
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
