<script setup lang="ts">
import { ref, shallowReactive, shallowRef } from "vue";
import { useRoute } from "vue-router";

import {
	InfiniteScrollCustomEvent,
	IonInfiniteScroll,
	IonInfiniteScrollContent,
	IonList,
} from "@ionic/vue";

import AppPage from "@/components/AppPage.vue";
import GenericSongItem from "@/components/GenericSongItem.vue";
import SkeletonItem from "@/components/SkeletonItem.vue";

import {
	Artist,
	Filled,
	filledArtist,
	Song,
	SongPreview,
	SongType,
} from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { useNavigation } from "@/stores/navigation";
import { take } from "@/utils/iterators";
import { watchAsync } from "@/utils/vue";

const musicPlayer = useMusicPlayer();
const navigation = useNavigation();
const route = useRoute();

const songs = shallowReactive<(Song | SongPreview)[]>([]);
const iterator = shallowRef<AsyncGenerator<Song | SongPreview>>();

const isLoading = ref(true);
const artist = ref<Filled<Artist>>();
watchAsync(
	() => [route.params.artistType, route.params.artistId],
	async ([artistType, artistId]) => {
		if (!artistType || !artistId) {
			return;
		}

		if (artist.value?.id === artistId && artist.value?.type === artistType) {
			return;
		}

		const $artist = await musicPlayer.services.getArtist(
			route.params.artistType as SongType,
			route.params.artistId as string,
		);

		artist.value = $artist && filledArtist($artist);
	},
	{ immediate: true },
);

async function fetchMoreSongs(): Promise<void> {
	if (!iterator.value) return;
	for await (const result of take(iterator.value, 25)) {
		songs.push(result);
	}
}

watchAsync(artist, async (artist) => {
	songs.length = 0;
	if (!artist) return;

	iterator.value = musicPlayer.services.getArtistsSongs(artist);
	isLoading.value = true;
	await fetchMoreSongs();
	isLoading.value = false;
});

async function loadMoreSongs(event: InfiniteScrollCustomEvent): Promise<void> {
	if (!artist.value) return;
	await fetchMoreSongs();
	await event.target.complete();
}
</script>

<template>
	<AppPage title="Top Songs">
		<ion-list v-if="isLoading" class="songs-list">
			<SkeletonItem v-for="i in 25" :key="i" />
		</ion-list>
		<ion-list v-else-if="artist">
			<GenericSongItem
				v-for="song in songs"
				@item-click="musicPlayer.playSongNow(song)"
				@context-menu-click="navigation.goToSong(song)"
				:song
				:key="song.id"
				:title="song.title"
				:album="song.album"
				:artwork="song.artwork"
				:disabled="!song.available"
			/>
		</ion-list>

		<ion-infinite-scroll v-if="artist" @ion-infinite="loadMoreSongs">
			<ion-infinite-scroll-content loading-spinner="dots" />
		</ion-infinite-scroll>
	</AppPage>
</template>
