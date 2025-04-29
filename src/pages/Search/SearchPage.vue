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
import { sadOutline as sadIcon, search as searchIcon } from "ionicons/icons";
import { ref, shallowRef } from "vue";

import { useMusicPlayer } from "@/stores/music-player";

import AppPage from "@/components/AppPage.vue";
import SkeletonItem from "@/components/SkeletonItem.vue";
import { SearchFilter, SearchResultItem } from "@/services/Music/MusicService";
import { take } from "@/utils/iterators";
import AlbumSearchResult from "./components/AlbumSearchResult.vue";
import ArtistSearchResult from "./components/ArtistSearchResult.vue";
import SongSearchResult from "./components/SongSearchResult.vue";

const musicPlayer = useMusicPlayer();

const searchTerm = ref("");
const searchSuggestions = ref<string[]>([]);

const searchResults = ref<SearchResultItem[]>([]);

const offset = ref(0);
const searched = ref(false);
const isLoading = ref(false);
const filter = ref<SearchFilter>("top-results");
const iterator = shallowRef<AsyncGenerator<SearchResultItem>>();

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

async function fetchMoreResults(): Promise<void> {
	if (!iterator.value) return;
	for await (const result of take(iterator.value, 25)) {
		searchResults.value.push(result);
	}
}

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

	await iterator.value?.return(null);
	iterator.value = musicPlayer.services.searchForItems(term, filter.value);

	await fetchMoreResults();

	isLoading.value = false;
	searched.value = true;
}

async function loadMoreContent(event: InfiniteScrollCustomEvent): Promise<void> {
	await fetchMoreResults();
	await event.target.complete();
}
</script>

<template>
	<AppPage title="Search" class="search-page">
		<div id="toolbars">
			<ion-toolbar class="searchbar">
				<ion-searchbar
					:debounce="50"
					v-model="searchTerm"
					cancel-button-text="Cancel"
					show-cancel-button="focus"
					inputmode="search"
					enterkeyhint="search"
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
		</div>

		<div>
			<h2 class="no-results-found" v-if="searched && !isLoading && !searchResults.length">
				<ion-icon :icon="sadIcon" />
				No results found
			</h2>

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
.ios {
	.search-page ion-header {
		.header-background {
			backdrop-filter: none !important;
		}

		& > ion-toolbar {
			--background: transparent;
			--border-color: transparent;
		}
	}

	ion-header.header-collapse-condense-inactive ~ ion-content {
		& > #toolbars::before {
			opacity: 0;
		}
	}
}
</style>

<style scoped>
.ios {
	#toolbars {
		&::before {
			transition:
				opacity,
				backdrop-filter,
				75ms ease-in-out;

			content: "";
			position: absolute;

			--offset: calc(44px + var(--ion-safe-area-top));
			top: calc(var(--offset) * -1);
			left: 0;
			width: 100%;
			height: calc(100% + var(--offset));

			background: color-mix(
				in srgb,
				var(
						--ion-toolbar-background,
						var(--ion-color-step-50, var(--ion-background-color-step-50, #f7f7f7))
					)
					80%,
				transparent
			);
			backdrop-filter: saturate(180%) blur(20px);
		}

		position: sticky;
		top: 0;
		z-index: 10;

		& > ion-toolbar {
			--border-color: transparent;
			--background: transparent;
		}

		& > .searchbar > ion-searchbar {
			padding-block: 0;
		}

		& > .filters {
			padding-inline: 12px;
		}
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
}

.no-results-found {
	display: flex;
	justify-content: center;
	align-items: center;
	gap: 0.25rem;
	font-size: 1.4rem;
}

#search-suggestions {
	& > .search-suggestion {
		& ion-icon {
			font-size: 1.1em;
		}
	}
}
</style>
