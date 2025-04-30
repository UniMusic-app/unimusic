<script lang="ts" setup>
import { ref } from "vue";

import ContextMenu from "@/components/ContextMenu.vue";
import LocalImg from "@/components/LocalImg.vue";
import { IonIcon, IonItem, IonLabel, IonNote } from "@ionic/vue";
import { personOutline as artistIcon, compassOutline as compassIcon } from "ionicons/icons";

import { Artist, ArtistPreview } from "@/services/Music/objects";
import { kindToDisplayName, songTypeToDisplayName } from "@/utils/songs";

const {
	button = true,
	title,
	type,
	kind,
	artwork,
	routerLink,
} = defineProps<
	Pick<Partial<Artist | ArtistPreview>, "type" | "kind" | "artwork" | "title"> & {
		reorder?: boolean;
		button?: boolean;
		disabled?: boolean;
		routerLink?: string;
	}
>();

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
		<ion-item
			:router-link
			:button
			:disabled
			:detail="contextMenuOpen"
			@click="emitClick"
			:class="$attrs.class"
		>
			<LocalImg
				slot="start"
				:src="artwork"
				:alt="`Artwork for artist '${title}'`"
				:fallback-icon="artistIcon"
			/>

			<ion-label>
				<h1>{{ title }}</h1>
				<ion-note>
					<p v-if="kind">
						<ion-icon :icon="artistIcon" />
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

	& > .local-img {
		transition: var(--context-menu-transition);

		--img-border-radius: 999px;
		--img-width: 96px;
		--img-height: auto;
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
				align-items: start;
				font-size: 1.1em;
			}
		}
	}
}

ion-item {
	& > .local-img {
		pointer-events: none;

		--img-border-radius: 999px;
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
}
</style>
