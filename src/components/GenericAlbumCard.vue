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
	<ContextMenu
		position="top"
		:class="$props.class"
		ref="contextMenu"
		@visibilitychange="contextMenuOpen = $event"
	>
		<ion-card
			:router-link
			:button
			:disabled
			:detail="contextMenuOpen"
			@click="emitClick"
			class="album-card"
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
.context-menu-item .album-card {
	width: 100%;
}

.context-menu {
	:global(&:has(.album-card)) {
		--move-item-width: min(80vw, 400px);
		--move-item-height: calc(var(--move-item-width) * 1.165);
	}

	&.opened .album-card {
		background: var(--ion-background-color-step-100, #fff);
		--border-color: transparent;

		border-radius: 24px;
		padding: 12px;

		& > .local-img {
			border-radius: 12px;
			border: 1px solid #0002;
		}
	}
}

.album-card,
.skeleton-card {
	margin: 0;
	background: transparent;
	box-shadow: none;
	border-radius: 0;

	user-select: none;
	-webkit-user-drag: none;

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
