<script setup lang="ts">
import { useLocalStorage } from "@vueuse/core";
import { onMounted, ref, shallowRef } from "vue";

import {
	InfiniteScrollCustomEvent,
	IonInfiniteScroll,
	IonInfiniteScrollContent,
	IonRefresher,
	IonRefresherContent,
	RefresherCustomEvent,
} from "@ionic/vue";

import { HomeFeedItem } from "@/services/Music/MusicService";
import { useMusicPlayer } from "@/stores/music-player";

import AppPage from "@/components/AppPage.vue";
import SearchResultItem from "@/components/SearchResultItem.vue";

import LocalImg from "@/components/LocalImg.vue";
import SearchResultCard from "@/components/SearchResultCard.vue";
import { take } from "@/utils/iterators";
import { sleep } from "@/utils/time";

const musicPlayer = useMusicPlayer();

const iterator = shallowRef<AsyncGenerator<HomeFeedItem>>();
const homeFeed = useLocalStorage<HomeFeedItem[]>("homeFeed", []);
const isLoading = ref(homeFeed.value.length === 0);

onMounted(async () => {
	await sleep(500);

	isLoading.value = true;
	iterator.value = musicPlayer.services.getHomeFeed();
	const feed: HomeFeedItem[] = [];
	for await (const item of take(iterator.value, 12)) {
		feed.push(item);
	}
	homeFeed.value = feed;
	isLoading.value = false;
});

async function refreshAlbumLibrary(event: RefresherCustomEvent): Promise<void> {
	isLoading.value = true;
	await musicPlayer.services.refreshLibraryAlbums();
	homeFeed.value.length = 0;
	iterator.value = musicPlayer.services.getHomeFeed();
	for await (const album of take(iterator.value, 12)) {
		homeFeed.value.push(album);
	}
	isLoading.value = false;
	await event.target.complete();
}

async function loadMoreAlbums(event: InfiniteScrollCustomEvent): Promise<void> {
	isLoading.value = true;
	for await (const album of take(iterator.value!, 12)) {
		homeFeed.value.push(album);
	}
	isLoading.value = false;

	await event.target.complete();
}
</script>

<template>
	<AppPage :show-back-button="false" title="Home">
		<ion-refresher slot="fixed" @ion-refresh="refreshAlbumLibrary">
			<ion-refresher-content />
		</ion-refresher>

		<div id="home-page-content" class="ion-padding">
			<section
				v-for="{ title, description, style, items, relatedItems } in homeFeed"
				:key="title"
				class="home-feed-section"
			>
				<div class="header">
					<template v-if="relatedItems">
						<LocalImg
							v-for="item in relatedItems"
							:key="item.id"
							:src="item.artwork"
							:class="{ [item.kind.replace('Preview', '')]: true }"
						/>
					</template>
					<span class="titles">
						<!-- TODO: Add support for linking to relatedItems-->
						<h2>{{ description }}</h2>
						<h1>{{ title }}</h1>
					</span>
				</div>

				<!-- TODO: Add buttons to sections for scrolling -->
				<div v-if="style.type === 'list'" class="home-feed-list">
					<div class="list-items" :style="{ '--list-rows': style.rows ?? 2 }">
						<SearchResultItem v-for="item in items" :key="item.id" :item class="list-item" />
					</div>
				</div>
				<div v-else-if="style.type === 'items'" class="home-feed-items">
					<SearchResultCard
						v-for="item in items"
						:key="item.id"
						:item
						type="item"
						class="home-feed-item"
					/>
				</div>
				<div v-else-if="style.type === 'cards'" class="home-feed-cards">
					<SearchResultCard
						v-for="item in items"
						:key="item.id"
						:item
						:style="{ '--bg-color': item.artwork?.style?.bgColor ?? '#888888' }"
						type="card"
						class="home-feed-card"
					/>
				</div>
			</section>
		</div>

		<ion-infinite-scroll @ion-infinite="loadMoreAlbums">
			<ion-infinite-scroll-content loading-spinner="dots" />
		</ion-infinite-scroll>
	</AppPage>
</template>

<style scoped>
#home-page-content {
	:deep(& .context-menu-item) {
		content-visibility: visible;
	}

	& > .home-feed-section {
		& > .header {
			display: flex;
			align-items: center;

			& > .local-img {
				height: 2.75rem;
				margin-right: 0.5rem;

				border-radius: 4px;
				border: 0.55px solid #0002;

				&.artist {
					border-radius: 9999px;
				}

				&.album {
					border-radius: 12px;
				}
			}

			& > .titles {
				display: flex;
				flex-direction: column;
				margin-block: 1rem;

				& > h1 {
					font-weight: bold;
					font-size: 1.25rem;
					margin: 0;
				}

				& > h2 {
					font-weight: 550;
					font-size: 1rem;
					margin: 0;
					color: var(--ion-color-medium);
				}
			}
		}

		& > .home-feed-items,
		& > .home-feed-cards {
			display: flex;
			flex-wrap: nowrap;
			overflow: auto;
			width: 100%;
			gap: 16px;

			overflow-x: scroll;
			scroll-snap-type: x mandatory;
			scroll-padding-left: 8px;
			overscroll-behavior-x: auto;

			:deep(& .home-feed-item),
			:deep(& .home-feed-card) {
				scroll-snap-align: start;
			}

			:deep(& .context-menu-item .home-feed-item),
			:deep(& .context-menu-item .home-feed-card) {
				width: 192px;
			}

			&::-webkit-scrollbar {
				display: none;
			}
		}

		& > .home-feed-cards {
			padding: 16px;

			:deep(& .context-menu-item .home-feed-card),
			:deep(& .context-menu:not(.opened) .home-feed-card) {
				box-shadow: 0 0 12px var(--bg-color);
			}

			:deep(& .context-menu-item .home-feed-card) {
				width: 216px;

				& > .local-img {
					border-radius: 0;
				}
			}

			:deep(& .home-feed-card) {
				background: var(--bg-color);
				border-radius: 12px;

				& > ion-card-header {
					& > ion-card-title {
						color: white;
					}

					& > ion-card-subtitle {
						color: #dedede;
					}
				}
			}
		}

		& > .home-feed-list {
			width: 100%;

			overflow-x: scroll;
			scroll-snap-type: x mandatory;
			scroll-padding-left: 8px;
			overscroll-behavior-x: auto;

			scrollbar-width: none;
			&::-webkit-scrollbar {
				display: none;
			}

			& > .list-items {
				display: grid;
				grid-template-rows: repeat(var(--list-rows), 1fr);
				grid-auto-flow: column dense;
				grid-auto-columns: min(80vw, 290px);

				width: max-content;

				:global(& .context-menu:not(.opened) ion-item) {
					--padding-start: 8px;
				}

				:deep(& .list-item) {
					scroll-snap-align: start;

					margin: 0;
					background: transparent;
					box-shadow: none;

					--padding-start: 8px;
				}
			}
		}
	}
}
</style>
