<script setup lang="ts">
import { computedAsync } from "@vueuse/core";
import { computed, useTemplateRef, watch } from "vue";
import { useRoute, useRouter } from "vue-router";

import { IonButton, IonButtons, IonIcon, IonSkeletonText, IonThumbnail } from "@ionic/vue";
import { pencil as editIcon, play as playIcon } from "ionicons/icons";

import AppPage from "@/components/AppPage.vue";
import LocalImg from "@/components/LocalImg.vue";
import SongEditModal, { SongEditEvent } from "../components/SongEditModal.vue";

import WrappingMarquee from "@/components/WrappingMarquee.vue";
import { useSongMetadata } from "@/stores/metadata";
import { AnySong, useMusicPlayer } from "@/stores/music-player";
import { formatArtists } from "@/utils/songs";

const musicPlayer = useMusicPlayer();
const songMetadata = useSongMetadata();
const router = useRouter();
const route = useRoute();

const previousRouteName = computed(() => {
	const { state } = router.options.history;
	if (!("back" in state)) return "Songs";
	return String(router.resolve(state.back as any)?.name);
});

const song = computedAsync(
	async () =>
		await musicPlayer.services.getSong(
			route.params.type as AnySong["type"],
			route.params.id as string,
		),
);

const isSingle = computed(() => !!song.value?.album?.includes("- Single"));

const editSongButton = useTemplateRef("edit-song");
watch(
	[song, editSongButton],
	([song, button]) => {
		if (song && button && route.hash === "#edit") {
			console.log(button.$el);
			button.$el.click();
		}
	},
	{ immediate: true },
);

async function editSong(event: SongEditEvent): Promise<void> {
	if (!song.value) return;

	songMetadata.setMetadata(song.value.id, event);
	song.value = await musicPlayer.services.refreshSong(song.value);
}

async function playNow(): Promise<void> {
	if (song.value) {
		if (musicPlayer.state?.currentSong?.id === song.value.id) {
			await musicPlayer.play();
		} else {
			await musicPlayer.state.addToQueue(song.value, musicPlayer.state.queueIndex);
		}
	}
}
</script>

<template>
	<AppPage :back-button="previousRouteName">
		<template #toolbar-end>
			<ion-buttons>
				<ion-button ref="edit-song" id="edit-song" v-if="song">
					<ion-icon slot="icon-only" :icon="editIcon" />
				</ion-button>
			</ion-buttons>
		</template>

		<SongEditModal v-if="song" :song trigger="edit-song" @change="editSong" />

		<div id="song-content" v-if="song">
			<LocalImg :src="song.artwork" />
			<h1 class="ion-text-nowrap">
				<WrappingMarquee :text="song.title ?? 'Unknown title'" />
			</h1>
			<h2>{{ formatArtists(song.artists) }}</h2>
			<h3 v-if="!isSingle">{{ song.album }}</h3>

			<ion-button strong @click="playNow">
				<ion-icon slot="start" :icon="playIcon" />
				Play
			</ion-button>
		</div>
		<div id="song-loading-content" v-else>
			<ion-thumbnail>
				<ion-skeleton-text :animated="true" />
			</ion-thumbnail>
			<h1><ion-skeleton-text :animated="true" /></h1>
			<h2><ion-skeleton-text :animated="true" /></h2>
		</div>
	</AppPage>
</template>

<style scoped>
@keyframes fade-in {
	from {
		opacity: 0;
	}

	to {
		opacity: 1;
	}
}

#song-content {
	text-align: center;

	animation: fade-in 350ms;

	& > h1 {
		font-weight: 550;
		margin-top: 0;
		margin-bottom: 0.25rem;
		mask-image: linear-gradient(to right, transparent, black 10% 90%, transparent);
		--marquee-duration: 20s;
		--marquee-align: center;
	}

	& > h2 {
		font-size: 1.25rem;
		font-weight: bold;
		margin-top: 0;
	}

	& > h3 {
		font-size: 1rem;
		font-weight: 450;
		margin-top: 0;
	}

	& > ion-button {
		&::part(native) {
			width: 33%;
			margin-inline: auto;
		}

		width: 100%;
		padding-bottom: 1rem;
	}

	& > .song-img {
		margin-inline: auto;

		--img-height: 192px;
		--img-width: auto;

		--shadow-color: rgba(var(--ion-color-dark-rgb), 0.1);

		border-radius: 12px;
		box-shadow: 0 0 12px var(--shadow-color);
		margin-block: 24px;
		background-color: rgba(var(--ion-color-dark-rgb), 0.08);

		& > .fallback {
			--size: 36px;
			filter: drop-shadow(0 0 12px var(--shadow-color));
		}
	}
}

#song-loading-content {
	display: flex;
	flex-direction: column;
	align-items: center;

	animation: fade-in 350ms;

	& > ion-thumbnail {
		margin-inline: auto;
		margin-block: 24px;

		height: 192px;
		width: 192px;
		--border-radius: 12px;
	}

	& > h1 {
		width: 50%;
		height: 20px;
		margin-top: 0;
		margin-bottom: 0.25rem;
	}

	& > h2 {
		width: 40%;
		margin-top: 0;
	}
}
</style>
