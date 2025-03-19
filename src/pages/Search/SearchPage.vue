<script setup lang="ts">
import {
	IonHeader,
	IonIcon,
	IonItem,
	IonLabel,
	IonList,
	IonSearchbar,
	IonToolbar,
} from "@ionic/vue";
import { watchDebounced } from "@vueuse/core";
import {
	addOutline as addIcon,
	documentOutline as documentIcon,
	hourglassOutline as hourglassIcon,
	playOutline as playIcon,
	search as searchIcon,
} from "ionicons/icons";
import { ref } from "vue";

import type { SongSearchResult } from "@/services/Music/MusicService";
import { AnySong, useMusicPlayer } from "@/stores/music-player";

import AppPage from "@/components/AppPage.vue";
import GenericSongItem from "@/components/GenericSongItem.vue";
import SkeletonItem from "@/components/SkeletonItem.vue";

const musicPlayer = useMusicPlayer();

const searchTerm = ref("");
const searchSuggestions = ref<string[]>([]);
const searchResults = ref<SongSearchResult[]>([]);

const searched = ref(false);

const isLoading = ref(false);

watchDebounced(
	searchTerm,
	async (searchTerm) => {
		searchSuggestions.value = await musicPlayer.services.searchHints(searchTerm);
	},
	{ debounce: 150, maxWait: 500 },
);

async function searchFor(term: string): Promise<void> {
	if (!term) return;

	isLoading.value = true;
	searchResults.value = await musicPlayer.services.searchSongs(term);
	isLoading.value = false;
	searched.value = true;
}

async function playNow(searchResult: SongSearchResult<AnySong>): Promise<void> {
	const song = await musicPlayer.services.getSongFromSearchResult(searchResult);
	await musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex);
}

async function playNext(searchResult: SongSearchResult<AnySong>): Promise<void> {
	const song = await musicPlayer.services.getSongFromSearchResult(searchResult);
	await musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex + 1);
}

async function addToQueue(searchResult: SongSearchResult<AnySong>): Promise<void> {
	const song = await musicPlayer.services.getSongFromSearchResult(searchResult);
	await musicPlayer.state.addToQueue(song);
}
</script>

<template>
	<AppPage title="Search">
		<ion-header id="search" translucent>
			<ion-toolbar>
				<ion-searchbar
					:debounce="50"
					v-model="searchTerm"
					cancel-button-text="Cancel"
					show-cancel-button="focus"
					inputmode="search"
					enterkeyhint="search"
					@ion-input="searched = false"
					@ion-change="searchFor(<string>$event.detail.value)"
				/>
			</ion-toolbar>
		</ion-header>

		<div>
			<ion-list v-if="!(searched || isLoading)" id="search-suggestions">
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

			<ion-list v-if="isLoading">
				<SkeletonItem v-for="i in 10" :key="i" />
			</ion-list>
			<ion-list v-else id="search-song-items">
				<GenericSongItem
					v-for="(searchResult, i) of searchResults"
					:key="i"
					:title="searchResult.title"
					:artists="searchResult.artists"
					:artwork="searchResult.artwork"
					:type="searchResult.type"
					@item-click="playNow(searchResult)"
				>
					<template #options>
						<ion-item :button="true" :detail="false" @click="playNow(searchResult)">
							<ion-icon aria-hidden="true" :icon="playIcon" slot="end" />
							Play now
						</ion-item>

						<ion-item :button="true" :detail="false" @click="playNext(searchResult)">
							<ion-icon aria-hidden="true" :icon="hourglassIcon" slot="end" />
							Play next
						</ion-item>

						<ion-item :button="true" :detail="false" @click="addToQueue(searchResult)">
							<ion-icon aria-hidden="true" :icon="addIcon" slot="end" />
							Add to queue
						</ion-item>
						<!-- FIXME: Modify metadata
						<ion-item :button="true" :detail="false" @click="modifyMetadata(searchResult)">
							<ion-icon aria-hidden="true" :icon="documentIcon" slot="end" />
							Modify metadata
						</ion-item> -->
					</template>
				</GenericSongItem>
			</ion-list>
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
#search {
	position: sticky;
	top: 0;

	& > ion-toolbar {
		padding-top: 0;
	}
}

ion-searchbar {
	& ion-icon {
		font-size: 0.1em;
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
