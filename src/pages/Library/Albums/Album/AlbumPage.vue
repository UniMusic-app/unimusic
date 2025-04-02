<script lang="ts" setup>
import { IonHeader, IonList, IonTitle, IonToolbar } from "@ionic/vue";
import { computedAsync } from "@vueuse/core";
import { computed, watchEffect } from "vue";
import { useRoute, useRouter } from "vue-router";

import AppPage from "@/components/AppPage.vue";
import GenericSongItem from "@/components/GenericSongItem.vue";
import LocalImg from "@/components/LocalImg.vue";
import WrappingMarquee from "@/components/WrappingMarquee.vue";

import { AnySong, useMusicPlayer } from "@/stores/music-player";

const musicPlayer = useMusicPlayer();
const router = useRouter();
const route = useRoute();

const previousRouteName = computed(() => {
	const { state } = router.options.history;
	if (!("back" in state)) return "Albums";
	return String(router.resolve(state.back as any)?.name);
});

const album = computedAsync(async () => {
	const { albumType, albumId, songType, songId } = route.params;

	if (songType) {
		const song = await musicPlayer.services.getSong(songType as AnySong["type"], songId as string);
		return song && (await musicPlayer.services.getSongsAlbum(song));
	}

	return await musicPlayer.services.getAlbum(albumType as AnySong["type"], albumId as string);
});

watchEffect(() => {
	console.log(album.value);
});
</script>

<template>
	<AppPage :title="album?.title" :show-content-header="false" :back-button="previousRouteName">
		<div id="album-content" v-if="album">
			<LocalImg :src="album.artwork" />

			<ion-header collapse="condense">
				<ion-toolbar>
					<ion-title class="ion-text-nowrap" size="large">
						<WrappingMarquee :text="album.title" />
					</ion-title>
				</ion-toolbar>
			</ion-header>

			<h2>
				<a
					class="artist"
					role="link"
					aria-roledescription="Go to artist"
					v-for="artist in album.artists"
					:key="artist.id"
				>
					{{ artist.name }}
				</a>
			</h2>

			<ion-list>
				<GenericSongItem
					v-for="song in album.songs"
					:key="song.id"
					:title="song.title"
					:artists="song.artists"
					:artwork="song.artwork"
					:type="song.type"
				>
					<template #options></template>
				</GenericSongItem>
			</ion-list>
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

#album-content {
	text-align: center;

	animation: fade-in 350ms;

	& > ion-header {
		mask-image: linear-gradient(to right, transparent, black 10% 90%, transparent);

		& ion-title {
			transform-origin: top center;
			justify-content: center;

			font-weight: 550;
			margin: 0;

			--marquee-duration: 20s;
			--marquee-align: center;
		}
	}

	& > h2 {
		font-size: 1.25rem;
		font-weight: 550;

		margin-top: 0;
		margin-inline: auto;

		& > a {
			cursor: pointer;
			color: var(--ion-color-dark-rgb);

			&:hover {
				opacity: 80%;

				@media (pointer: fine) {
					text-decoration: underline;
				}
			}

			&:active {
				opacity: 60%;
			}
		}
	}

	& > .local-img {
		margin-inline: auto;

		--img-height: 192px;
		--img-width: auto;

		--shadow-color: rgba(var(--ion-color-dark-rgb), 0.1);

		border-radius: 12px;
		box-shadow: 0 0 12px var(--shadow-color);
		margin-block: 24px;
		background-color: rgba(var(--ion-color-dark-rgb), 0.08);
	}
}
</style>
