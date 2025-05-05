<script lang="ts" setup>
import { ref } from "vue";

import { useMusicPlayer } from "@/stores/music-player";

import { IonBadge, IonIcon, IonItem, IonLabel, useIonRouter } from "@ionic/vue";
import {
	addOutline as addIcon,
	hourglassOutline as hourglassIcon,
	playOutline as playIcon,
} from "ionicons/icons";

import ContextMenu from "@/components/ContextMenu.vue";
import LocalImg from "@/components/LocalImg.vue";
import { Album, AlbumSong, Filled } from "@/services/Music/objects";

const { albumSong, album } = defineProps<{
	albumSong: Filled<AlbumSong>;
	album: Filled<Album>;
}>();

const musicPlayer = useMusicPlayer();
const router = useIonRouter();

const contextMenuOpen = ref(false);

async function click(): Promise<void> {
	if (contextMenuOpen.value) {
		router.push(`/items/songs/${albumSong.song.type}/${albumSong.song.id}`);
	} else {
		await playAlbumSong();
	}
}

async function playAlbumSong(): Promise<void> {
	const song = await musicPlayer.services.retrieveSong(albumSong.song);
	await musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex);
}
</script>

<template>
	<ContextMenu
		:disabled="!albumSong.song.available"
		ref="contextMenu"
		@visibilitychange="contextMenuOpen = $event"
		position="top"
	>
		<ion-item
			class="album-disc-item"
			:disabled="!albumSong.song.available"
			button
			lines="full"
			@click="click"
		>
			<ion-badge color="light" slot="start">
				{{ albumSong.trackNumber ?? "!" }}
			</ion-badge>

			<LocalImg
				v-if="album.artwork"
				slot="start"
				:src="album.artwork"
				:alt="`Artwork for song '${albumSong.song.title}' from album '${album.title}'`"
			/>

			<ion-label>{{ albumSong.song.title ?? "Unknown title" }}</ion-label>
		</ion-item>

		<template #options>
			<slot name="options">
				<ion-item :button="true" :detail="false" @click="musicPlayer.playSongNow(albumSong.song)">
					<ion-icon aria-hidden="true" :icon="playIcon" slot="end" />
					Play now
				</ion-item>

				<ion-item :button="true" :detail="false" @click="musicPlayer.playSongNext(albumSong.song)">
					<ion-icon aria-hidden="true" :icon="hourglassIcon" slot="end" />
					Play next
				</ion-item>

				<ion-item :button="true" :detail="false" @click="musicPlayer.playSongLast(albumSong.song)">
					<ion-icon aria-hidden="true" :icon="addIcon" slot="end" />
					Add to queue
				</ion-item>
			</slot>
		</template>
	</ContextMenu>
</template>

<style scoped>
.context-menu {
	:global(&:has(.album-disc-item)) {
		--move-item-height: 8.65rem;
	}

	&.opened .album-disc-item {
		--background: var(--ion-background-color-step-100, #fff);

		border-radius: 24px;
		--border-color: transparent;

		--padding-top: 12px;
		--padding-bottom: 12px;
		--padding-start: 12px;
		--padding-end: 12px;

		& > ion-badge {
			display: none;
		}

		& > .local-img {
			display: block;
		}

		& > ion-label {
			white-space: normal;
			font-weight: 550;
			font-size: 1.2rem;
		}
	}
}

.album-disc-item {
	&.disc-header {
		font-size: 1.25rem;
		font-weight: 550;
	}

	& > .local-img {
		display: none;
		transition: var(--context-menu-transition);

		--img-border-radius: 12px;
		--img-width: 96px;
		--img-height: auto;
	}
}
</style>
