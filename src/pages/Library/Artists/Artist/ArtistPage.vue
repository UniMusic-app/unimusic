<script lang="ts" setup>
import AppPage from "@/components/AppPage.vue";
import { Artist, Filled, filledArtist, SongType } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { useRoute } from "vue-router";

import {
	IonHeader,
	IonIcon,
	IonSkeletonText,
	IonThumbnail,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";
import { chevronForward as chevronForwardIcon } from "ionicons/icons";

import GenericAlbumCard from "@/components/GenericAlbumCard.vue";
import GenericSongItem from "@/components/GenericSongItem.vue";
import LocalImg from "@/components/LocalImg.vue";
import WrappingMarquee from "@/components/WrappingMarquee.vue";
import { useNavigation } from "@/stores/navigation";
import { watchAsync } from "@/utils/vue";
import { useWindowSize } from "@vueuse/core";
import { ref } from "vue";

const musicPlayer = useMusicPlayer();
const navigation = useNavigation();
const route = useRoute();

const artist = ref<Filled<Artist>>();
watchAsync(
	() => [route.params.artistType, route.params.artistId],
	async ([artistType, artistId]) => {
		if (!artistType || !artistId) return;

		const $artist = await musicPlayer.services.getArtist(
			route.params.artistType as SongType,
			route.params.artistId as string,
		);

		artist.value = $artist && filledArtist($artist);
	},
	{ immediate: true },
);

const { width: windowWidth } = useWindowSize();
</script>

<template>
	<AppPage>
		<div id="artist-content" v-if="artist">
			<LocalImg size="large" v-if="artist.artwork" :src="artist.artwork" />

			<ion-header collapse="condense">
				<ion-toolbar>
					<ion-title class="ion-text-nowrap" size="large">
						<WrappingMarquee :text="artist.title ?? 'Unknown artist'" />
					</ion-title>
				</ion-toolbar>
			</ion-header>

			<section class="top-songs" v-if="artist.songs.length">
				<h1>
					<RouterLink :to="`/items/artists/${artist.type}/${artist.id}/songs`">Top Songs</RouterLink>
					<ion-icon :icon="chevronForwardIcon" />
				</h1>

				<div class="top-songs-container">
					<div
						class="top-songs-items"
						:style="{
							'--top-songs-rows': Math.min(3, Math.floor((artist.songs.length * 280) / windowWidth)),
						}"
					>
						<GenericSongItem
							@item-click="musicPlayer.playSongNow(song)"
							@context-menu-click="navigation.goToSong(song)"
							class="song-item"
							v-for="song in artist.songs"
							:song
							:key="song.id"
							:title="song.title"
							:artwork="song.artwork"
							:available="song.available"
							:explicit="song.explicit"
							:duration="song.duration"
							:album="song.album"
						/>
					</div>
				</div>
			</section>

			<section class="albums" v-if="artist.albums.length">
				<h1>Albums</h1>
				<div class="album-cards-container">
					<div class="album-cards">
						<GenericAlbumCard
							class="album-card"
							v-for="album in artist.albums"
							:album
							:key="album.id"
							:title="album.title"
							:artwork="album.artwork"
							:router-link="`/items/albums/album/${album.type}/${album.id}`"
						/>
					</div>
				</div>
			</section>
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

	& > ion-header {
		& .wrapping {
			mask-image: linear-gradient(to right, transparent, black 10% 90%, transparent);
		}

		width: max-content;
		max-width: 100%;
		margin-inline: auto;

		& ion-title {
			transform-origin: top center;

			font-weight: bold;
			margin: 0;

			--marquee-duration: 20s;
			--marquee-align: center;
		}
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

		--img-width: auto;
		--img-max-width: calc(100vw - 24px);
		--img-max-height: 192px;

		--shadow-color: rgba(var(--ion-color-dark-rgb), 0.1);

		border-radius: 12px;
		box-shadow: 0 0 12px var(--shadow-color);
		margin-block: 24px;
		background-color: rgba(var(--ion-color-dark-rgb), 0.08);
	}

	& > .top-songs {
		display: flex;
		flex-direction: column;
		align-items: start;

		& > h1 {
			display: inline-flex;
			align-items: center;
			margin-left: 0.5em;
			font-weight: bold;

			& > a {
				color: var(--ion-color-dark-rgb);
				text-decoration: none;
			}

			& > ion-icon {
				color: var(--ion-color-medium);
			}
		}

		& > .top-songs-container {
			width: 100%;

			overflow-x: scroll;
			scroll-snap-type: x mandatory;
			scroll-padding-left: 8px;
			overscroll-behavior-x: auto;

			scrollbar-width: none;
			&::-webkit-scrollbar {
				display: none;
			}

			& > .top-songs-items {
				display: grid;
				grid-template-rows: repeat(var(--top-songs-rows), 1fr);
				grid-auto-flow: column dense;
				grid-auto-columns: min(80vw, 290px);

				width: max-content;

				:global(& .context-menu:not(.opened) ion-item) {
					--padding-start: 8px;
				}

				:deep(& .song-item) {
					scroll-snap-align: start;

					margin: 0;
					background: transparent;
					box-shadow: none;

					--padding-start: 8px;
				}
			}
		}
	}

	& > .albums {
		display: flex;
		flex-direction: column;
		align-items: start;
		margin-bottom: 2em;

		& > h1 {
			margin-left: 0.5em;
			font-weight: bold;
		}

		& > .album-cards-container {
			width: 100%;

			overflow-x: scroll;
			scroll-snap-type: x mandatory;
			scroll-padding-left: 8px;
			overscroll-behavior-x: auto;

			scrollbar-width: none;
			&::-webkit-scrollbar {
				display: none;
			}

			& > .album-cards {
				display: flex;
				flex-direction: row;

				gap: 8px;
				padding-left: 8px;

				:deep(& .album-card) {
					scroll-snap-align: start;
					width: 128px;
				}
			}
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
