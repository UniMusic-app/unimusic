<template>
	<ion-page>
		<AppHeader :showToolbar="!isSearching">
			<template #toolbar>
				<ion-title>Search</ion-title>
			</template>

			<template #trailing>
				<ion-toolbar>
					<ion-searchbar
						id="searchbar"
						:class="{ searching: isSearching }"
						:debounce="150"
						v-model="search"
						cancel-button-text="Cancel"
						show-cancel-button="focus"
						inputmode="search"
						enterkeyhint="search"
						@ion-focus="isSearching = true"
						@ion-cancel="isSearching = false"
						@ion-blur="!search && (isSearching = false)"
						@ion-input="updateSearchHints"
						@keyup.enter="searchFor($event.target.value)"
					/>

					<ion-progress-bar v-if="isLoading" type="indeterminate" />
				</ion-toolbar>
			</template>
		</AppHeader>

		<ion-content :fullscreen="true">
			<ion-list id="search-suggestions" v-if="isSearching && searchSuggestions.length">
				<ion-item
					button
					class="search-suggestion"
					v-for="suggestion in searchSuggestions"
					:key="suggestion"
					@click="searchFor(suggestion)"
				>
					<ion-icon :icon="searchIcon" />
					<ion-label>
						{{ suggestion }}
					</ion-label>
				</ion-item>
			</ion-list>

			<ion-list v-if="!isSearching && search" id="search-results">
				<ion-list>
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

							<ion-item :button="true" :detail="false" @click="modifyMetadata(searchResult)">
								<ion-icon aria-hidden="true" :icon="documentIcon" slot="end" />
								Modify metadata
							</ion-item>
						</template>
					</GenericSongItem>
				</ion-list>
			</ion-list>
		</ion-content>

		<AppFooter />
	</ion-page>
</template>

<script setup lang="ts">
import {
	IonContent,
	IonIcon,
	IonItem,
	IonLabel,
	IonList,
	IonPage,
	IonProgressBar,
	IonSearchbar,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";
import {
	addOutline as addIcon,
	documentOutline as documentIcon,
	hourglassOutline as hourglassIcon,
	playOutline as playIcon,
	search as searchIcon,
} from "ionicons/icons";
import { ref } from "vue";

import type { SongSearchResult } from "@/services/MusicPlayer/MusicPlayerService";
import { AnySong, useMusicPlayer } from "@/stores/music-player";

import AppFooter from "@/components/AppFooter.vue";
import AppHeader from "@/components/AppHeader.vue";

import GenericSongItem from "@/components/GenericSongItem.vue";
import { createMetadataModal } from "@/components/SongMetadataModal.vue";

const musicPlayer = useMusicPlayer();
const search = ref("");
const isSearching = ref(false);
const searchSuggestions = ref<string[]>([]);

const searchResults = ref<SongSearchResult[]>([]);
const isLoading = ref(false);

async function updateSearchHints(): Promise<void> {
	searchSuggestions.value = await musicPlayer.services.searchHints(search.value);
}

async function searchFor(term: string): Promise<void> {
	isLoading.value = true;
	search.value = term;
	isSearching.value = false;
	await updateSearchResults();
	isLoading.value = false;
}

async function updateSearchResults(): Promise<void> {
	searchResults.value = await musicPlayer.services.searchSongs(search.value);
}

async function playNow(searchResult: SongSearchResult<AnySong>): Promise<void> {
	const song = await musicPlayer.services.getSongFromSearchResult(searchResult);
	musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex);
}

async function playNext(searchResult: SongSearchResult<AnySong>): Promise<void> {
	const song = await musicPlayer.services.getSongFromSearchResult(searchResult);
	musicPlayer.state.addToQueue(song, musicPlayer.state.queueIndex + 1);
}

async function addToQueue(searchResult: SongSearchResult<AnySong>): Promise<void> {
	const song = await musicPlayer.services.getSongFromSearchResult(searchResult);
	musicPlayer.state.addToQueue(song);
}

async function modifyMetadata(searchResult: SongSearchResult<AnySong>): Promise<void> {
	const song = await musicPlayer.services.getSongFromSearchResult(searchResult);
	const modal = await createMetadataModal(song);
	await modal.present();
	await modal.onDidDismiss();
}
</script>

<style scoped>
#search-suggestions {
	.search-suggestion {
		& > ion-icon {
			font-size: 1.25em;
			color: white;
			margin-right: 8px;
		}
	}
}
</style>
