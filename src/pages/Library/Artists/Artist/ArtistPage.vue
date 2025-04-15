<script lang="ts" setup>
import { computedAsync } from "@vueuse/core";

import AppPage from "@/components/AppPage.vue";
import { filledArtist, SongType } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { useRoute, useRouter } from "vue-router";

import LocalImg from "@/components/LocalImg.vue";
import WrappingMarquee from "@/components/WrappingMarquee.vue";
import { IonSkeletonText, IonThumbnail } from "@ionic/vue";
import { computed } from "vue";

const musicPlayer = useMusicPlayer();
const router = useRouter();
const route = useRoute();

const previousRouteName = computed(() => {
	const { state } = router.options.history;
	if (!("back" in state)) return "Songs";
	return String(router.resolve(state.back as any)?.name);
});

const artist = computedAsync(async () => {
	const artist = await musicPlayer.services.getArtist(
		route.params.artistType as SongType,
		route.params.artistId as string,
	);

	return artist && filledArtist(artist);
});
</script>

<template>
	<AppPage :back-button="previousRouteName">
		<div id="artist-content" v-if="artist">
			<LocalImg :src="artist.artwork" />
			<h1 class="ion-text-nowrap">
				<WrappingMarquee :text="artist.title ?? 'Unknown title'" />
			</h1>

			{{ artist.albums.length }}
			{{ artist.songs.length }}
		</div>
		<div id="artist-loading-content" v-else>
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

#artist-content {
	text-align: center;

	animation: fade-in 350ms;

	& > h1 {
		font-size: min(2.125rem, 61.2px);
		font-weight: bold;

		mask-image: linear-gradient(to right, transparent, black 10% 90%, transparent);

		margin-top: 0;
		margin-bottom: 0.25rem;

		--marquee-duration: 20s;
		--marquee-align: center;
	}

	& > .artist,
	& > .album {
		display: block;

		color: var(--ion-color-dark-rgb);
		text-decoration: none;

		width: max-content;

		margin-top: 0;
		margin-bottom: 10px;
		margin-inline: auto;

		cursor: pointer;
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

	& > .artist {
		font-size: 1.25rem;
		font-weight: 550;
	}

	& > .album {
		font-size: 1rem;
		font-weight: 450;
	}

	& > ion-button {
		&::part(native) {
			width: 33%;
			margin-inline: auto;
		}

		width: 100%;
		padding-bottom: 1rem;
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

		& > .fallback {
			--size: 36px;
			filter: drop-shadow(0 0 12px var(--shadow-color));
		}
	}
}

#artist-loading-content {
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
