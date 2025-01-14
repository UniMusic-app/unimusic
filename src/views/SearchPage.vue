<template>
	<ion-page>
		<app-header :showToolbar="!isSearching">
			<template #toolbar>
				<ion-title>Search</ion-title>
			</template>

			<template #trailing>
				<ion-toolbar>
					<ion-searchbar
						id="searchbar"
						:class="{
							searching: isSearching,
						}"
						:debounce="250"
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
				</ion-toolbar>
			</template>
		</app-header>

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

			<template v-if="!isSearching && search">
				<ion-list id="search-results">
					<ion-list>
						<MusicKitSongItem v-for="song in songs" :key="song.id" :song />
					</ion-list>
				</ion-list>
			</template>
		</ion-content>

		<app-footer />
	</ion-page>
</template>

<script setup lang="ts">
import {
	IonContent,
	IonPage,
	IonList,
	IonItem,
	IonTitle,
	IonToolbar,
	IonSearchbar,
	IonLabel,
	IonIcon,
} from "@ionic/vue";
import { search as searchIcon } from "ionicons/icons";
import AppHeader from "@/components/AppHeader.vue";
import AppFooter from "@/components/AppFooter.vue";
import { useMusicKit } from "@/stores/musickit";
import { ref } from "vue";
import MusicKitSongItem from "@/components/SongItem/MusicKitSongItem.vue";

const musicKit = useMusicKit();
const search = ref("");
const isSearching = ref(false);
const searchSuggestions = ref<string[]>([]);

const songs = ref<MusicKit.Songs[]>([]);

async function updateSearchHints(): Promise<void> {
	await musicKit.withMusic(async (music) => {
		if (!search.value) {
			searchSuggestions.value = [];
			return;
		}

		const response = await music.api.music<{ results: { terms: string[] } }>(
			"/v1/catalog/{{storefrontId}}/search/hints",
			{ term: search.value.replaceAll(" ", "+") },
		);

		const { terms } = response.data.results;
		searchSuggestions.value = terms;
	});
}

async function searchFor(term: string): Promise<void> {
	console.log("Searching for", term);
	search.value = term;
	isSearching.value = false;
	await updateSearchResults();
}

async function updateSearchResults(): Promise<void> {
	await musicKit.withMusic(async (music) => {
		if (!search.value) {
			return;
		}

		const response = await music.api.music<MusicKit.SearchResponse, MusicKit.CatalogSearchQuery>(
			"/v1/catalog/{{storefrontId}}/search",
			{
				term: search.value.replaceAll(" ", "+"),
				types: ["songs", "albums", "artists"],
				limit: 25,
			},
		);

		songs.value = (response?.data?.results?.songs?.data ?? []).filter((song) => song.attributes);
	});
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
