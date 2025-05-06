<script lang="ts" setup>
import { ref } from "vue";

import ContextMenu from "@/components/ContextMenu.vue";
import LocalImg from "@/components/LocalImg.vue";
import { IonIcon, IonItem, IonLabel, IonNote } from "@ionic/vue";
import {
	addOutline as addIcon,
	albumsOutline as albumIcon,
	compassOutline as compassIcon,
	hourglassOutline as hourglassIcon,
	playOutline as playIcon,
} from "ionicons/icons";

import { Album, AlbumPreview } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { kindToDisplayName, songTypeToDisplayName } from "@/utils/songs";

const {
	button = true,
	title,
	type,
	artwork,
	routerLink,
	album,
} = defineProps<
	Pick<Partial<Album | AlbumPreview>, "type" | "kind" | "artwork" | "title"> & {
		reorder?: boolean;
		button?: boolean;
		disabled?: boolean;
		routerLink?: string;
		album?: Album | AlbumPreview;
	}
>();

const musicPlayer = useMusicPlayer();

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
			class="album-item"
			:class="$attrs.class"
		>
			<LocalImg
				slot="start"
				:src="artwork"
				:alt="`Artwork for album '${title}'`"
				:fallback-icon="albumIcon"
			/>

			<ion-label>
				<h1>{{ title }}</h1>
				<ion-note>
					<p v-if="kind">
						<ion-icon :icon="albumIcon" />
						{{ kindToDisplayName(kind) }}
					</p>
					<p>
						<ion-icon :icon="compassIcon" />
						{{ songTypeToDisplayName(type) }}
					</p>
				</ion-note>
			</ion-label>
		</ion-item>

		<template #options>
			<slot name="options">
				<template v-if="album">
					<ion-item :button="true" :detail="false" @click="musicPlayer.playAlbumNow(album)">
						<ion-icon aria-hidden="true" :icon="playIcon" slot="end" />
						Play now
					</ion-item>

					<ion-item :button="true" :detail="false" @click="musicPlayer.playAlbumNext(album)">
						<ion-icon aria-hidden="true" :icon="hourglassIcon" slot="end" />
						Play next
					</ion-item>

					<ion-item :button="true" :detail="false" @click="musicPlayer.playAlbumLast(album)">
						<ion-icon aria-hidden="true" :icon="addIcon" slot="end" />
						Add to queue
					</ion-item>
				</template>
			</slot>
		</template>
	</ContextMenu>
</template>

<style scoped>
.context-menu {
	:global(&:has(.album-item)) {
		--move-item-height: 8.65rem;
	}

	&.opened .album-item {
		--background: var(--ion-background-color-step-100, #fff);

		border-radius: 24px;
		--border-color: transparent;

		--padding-top: 12px;
		--padding-bottom: 12px;
		--padding-start: 12px;
		--padding-end: 12px;

		& > .local-img {
			--img-width: 96px;
			--img-height: auto;
			border-radius: 24px;
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
	}
}

.album-item {
	& > .local-img {
		pointer-events: none;

		--img-width: auto;
		--img-height: 56px;
		border-radius: 16px;
		border: 0.55px solid #0002;
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
}
</style>
