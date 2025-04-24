<script setup lang="ts">
import {
	InfiniteScrollCustomEvent,
	IonIcon,
	IonInfiniteScroll,
	IonInfiniteScrollContent,
	IonItem,
	IonLabel,
	IonList,
	IonSearchbar,
	IonSegment,
	IonSegmentButton,
	IonToolbar,
} from "@ionic/vue";
import { watchDebounced } from "@vueuse/core";
import { search as searchIcon } from "ionicons/icons";
import { ref } from "vue";

import { useMusicPlayer } from "@/stores/music-player";

import AppPage from "@/components/AppPage.vue";
import SkeletonItem from "@/components/SkeletonItem.vue";
import { SearchFilter, SearchResult } from "@/services/Music/MusicService";
import AlbumSearchResult from "./components/AlbumSearchResult.vue";
import ArtistSearchResult from "./components/ArtistSearchResult.vue";
import SongSearchResult from "./components/SongSearchResult.vue";

const musicPlayer = useMusicPlayer();

const searchTerm = ref("");
const searchSuggestions = ref<string[]>([]);

const searchResults = ref<SearchResult[]>([]);

const offset = ref(0);
const searched = ref(false);
const isLoading = ref(false);
const filter = ref<SearchFilter>("top-results");

watchDebounced(
	searchTerm,
	async (searchTerm) => {
		if (!searchTerm) {
			searchSuggestions.value.length = 0;
			return;
		}

		let hitFirstSuggestion = false;
		for await (const hint of musicPlayer.services.searchHints(searchTerm)) {
			// Only clear the suggestions if at least one new one popped up
			// This makes it so that the suggestions don't jitter when searching
			if (!hitFirstSuggestion) {
				searchSuggestions.value.length = 0;
				hitFirstSuggestion = true;
			}

			searchSuggestions.value.push(hint);
		}
	},
	{ debounce: 150, maxWait: 500 },
);

watchDebounced(filter, async () => await searchFor(searchTerm.value), {
	debounce: 150,
	maxWait: 500,
});

async function fetchResults(term: string, offset: number, signal: AbortSignal): Promise<void> {
	for await (const result of musicPlayer.services.searchForItems(term, {
		filter: filter.value,
		signal,
		offset,
	})) {
		searchResults.value.push(result);
	}
}

let controller = new AbortController();
async function searchFor(term: string): Promise<void> {
	// Hide keyboard on mobile after searching
	const { activeElement } = document;
	if (activeElement instanceof HTMLElement) {
		activeElement.blur();
	}

	if (!term) return;

	searchTerm.value = term;

	isLoading.value = true;
	searchResults.value = [];
	offset.value = 0;
	controller.abort();
	controller = new AbortController();
	await fetchResults(term, 0, controller.signal);

	isLoading.value = false;
	searched.value = true;
}

async function loadMoreContent(event: InfiniteScrollCustomEvent): Promise<void> {
	await fetchResults(searchTerm.value, ++offset.value, controller.signal);
	await event.target.complete();
}
</script>

<template>
	<AppPage title="Search">
		<!-- FIXME: Search header being offset by those toolbars -->
		<template #header-trailing>
			<ion-toolbar>
				<ion-searchbar
					:debounce="50"
					v-model="searchTerm"
					cancel-button-text="Cancel"
					show-cancel-button="focus"
					inputmode="search"
					enterkeyhint="search"
					class="searchbar"
					@ion-input="searched = false"
					@keydown.enter="searchFor($event.target.value)"
				/>
			</ion-toolbar>
			<ion-toolbar class="filters">
				<ion-segment v-model="filter">
					<ion-segment-button value="top-results">Top Results</ion-segment-button>
					<ion-segment-button value="songs">Songs</ion-segment-button>
					<ion-segment-button value="artists">Artists</ion-segment-button>
					<ion-segment-button value="albums">Albums</ion-segment-button>
				</ion-segment>
			</ion-toolbar>
		</template>

		<div>
			<ion-list v-if="searchTerm && !(searched || isLoading)" id="search-suggestions">
				<ion-item
					button
					class="search-suggestion"
					v-for="suggestion in searchSuggestions"
					:key="suggestion"
					@click="searchFor(suggestion)"
					lines="full"
				>
					<ion-icon slot="start" :icon="searchIcon" />
					<ion-label>
						{{ suggestion }}
					</ion-label>
				</ion-item>
			</ion-list>
			<ion-list v-else id="search-song-items">
				<template v-for="(searchResult, i) of searchResults" :key="searchResult.id ?? i">
					<SongSearchResult
						v-if="searchResult.kind === 'song' || searchResult.kind === 'songPreview'"
						:search-result
					/>
					<ArtistSearchResult
						v-else-if="searchResult.kind === 'artist' || searchResult.kind === 'artistPreview'"
						:search-result
					/>
					<AlbumSearchResult
						v-else-if="searchResult.kind === 'album' || searchResult.kind === 'albumPreview'"
						:search-result
					/>
				</template>
			</ion-list>
			<ion-list v-if="isLoading && searchResults.length < 25">
				<SkeletonItem v-for="i in 25 - searchResults.length" :key="i + searchResults.length" />
			</ion-list>

			<ion-infinite-scroll v-if="searchTerm" @ion-infinite="loadMoreContent">
				<ion-infinite-scroll-content loading-spinner="dots" />
			</ion-infinite-scroll>
		</div>
	</AppPage>
</template>

<style global>
ion-header:not(#search) {
	& > ion-toolbar {
		--border-color: transparent;
	}
}
</style>

<style scoped>
.searchbar {
	transition: opacity, height, 150ms;
	opacity: var(--opacity-scale);
	height: calc(var(--min-height) + 8px);
	transform-origin: top center;
	transform: scaleY(var(--opacity-scale));
	padding-block: 0;
}

.filters {
	transition: opacity, height, 150ms;
	opacity: var(--opacity-scale);
	transform-origin: top center;
	transform: scaleY(var(--opacity-scale));
	padding-inline: 12px;
}

.header-collapse-condense-inactive {
	& > .searchbar,
	& > .filters {
		height: 0;
		opacity: 0;
	}
}

:not(.header-collapse-condense-inactive) {
	& > .searchbar {
		& ion-icon {
			font-size: 0.1em;
		}
	}
}

#search-suggestions {
	& > .search-suggestion {
		& ion-icon {
			font-size: 1.1em;
		}
	}
}
</style>
