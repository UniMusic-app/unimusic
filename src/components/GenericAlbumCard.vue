<script lang="ts" setup>
import { computed, ref } from "vue";

import ContextMenu from "@/components/ContextMenu.vue";
import LocalImg from "@/components/LocalImg.vue";
import {
	IonCard,
	IonCardHeader,
	IonCardSubtitle,
	IonCardTitle,
	IonIcon,
	IonItem,
} from "@ionic/vue";
import {
	addOutline as addIcon,
	compass as compassIcon,
	hourglassOutline as hourglassIcon,
	playOutline as playIcon,
} from "ionicons/icons";

import { Album, AlbumPreview, filledDisplayableArtist } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { formatArtists, songTypeToDisplayName } from "@/utils/songs";

const {
	title,
	type,
	artwork,
	artists,
	button = true,
	disabled,
	routerLink,
	album,
} = defineProps<
	Pick<Partial<Album>, "title" | "type" | "artists" | "artwork"> & {
		button?: boolean;
		disabled?: boolean;
		routerLink?: string;
		album?: Album | AlbumPreview;
	}
>();

const musicPlayer = useMusicPlayer();

const formattedArtists = computed(
	() => artists && formatArtists(artists?.map(filledDisplayableArtist)),
);
const displayName = computed(() => type && songTypeToDisplayName(type));

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
		<ion-card
			class="album-card"
			:router-link
			:button
			:disabled
			:detail="contextMenuOpen"
			@click="emitClick"
			:class="$attrs.class"
		>
			<LocalImg :src="artwork" :alt="`Artwork for album '${title}'`" />

			<ion-card-header>
				<ion-card-title class="ion-text-nowrap">
					{{ title }}
				</ion-card-title>
				<ion-card-subtitle class="ion-text-nowrap">
					<span v-if="type">
						<ion-icon :icon="compassIcon" />
						{{ displayName }}
					</span>

					{{ formattedArtists }}
				</ion-card-subtitle>
			</ion-card-header>
		</ion-card>

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
.context-menu > .context-menu-item > .album-card {
	width: 100%;
}

.context-menu.closed > .context-menu-item > .album-card {
	transition: var(--context-menu-transition);
}

.context-menu:not(.closed) > .context-menu-item > .album-card {
	transition: var(--context-menu-transition);
	background: var(--context-menu-item-background);

	border-radius: 24px;
	--border-color: transparent;
	padding: 12px;

	& > .local-img {
		border-radius: 12px;
		border: 1px solid #0002;
	}
}

.album-card,
.skeleton-card {
	margin: 0;
	background: transparent;
	box-shadow: none;
	border-radius: 0;

	width: 128px;

	& > .local-img {
		border-radius: 8px;
		border: 0.55px solid #0002;
		--img-width: 100%;
	}

	& > ion-card-header {
		padding: 8px;

		& > ion-card-title {
			font-size: 1rem;
			font-weight: 550;
			text-overflow: ellipsis;
			overflow: hidden;
		}

		& > ion-card-subtitle {
			font-size: 0.75rem;
			font-weight: 400;
			text-overflow: ellipsis;
			overflow: hidden;
		}
	}
}
</style>
