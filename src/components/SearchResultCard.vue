<script lang="ts" setup>
import { computed, ref } from "vue";

import ContextMenu from "@/components/ContextMenu.vue";
import LocalImg from "@/components/LocalImg.vue";
import {
	IonCard,
	IonCardHeader,
	IonCardSubtitle,
	IonCardTitle,
	IonIcon,
	IonItem,
	IonItemDivider,
} from "@ionic/vue";
import {
	addOutline as addIcon,
	compass as compassIcon,
	hourglassOutline as hourglassIcon,
	playOutline as playIcon,
	listCircleOutline as playlistAddIcon,
} from "ionicons/icons";

import { filledDisplayableArtist } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { formatArtists, songTypeToDisplayName } from "@/utils/songs";

import { openAddToPlaylistModal } from "@/pages/Library/Playlists/components/AddToPlaylistModal.vue";
import { SearchResultItem } from "@/services/Music/MusicService";
import { useNavigation } from "@/stores/navigation";

const { item } = defineProps<{ item: SearchResultItem }>();

const musicPlayer = useMusicPlayer();
const navigation = useNavigation();

const formattedArtists = computed(() =>
	item.kind === "song" || item.kind === "songPreview"
		? formatArtists(item.artists.map(filledDisplayableArtist))
		: undefined,
);

const displayName = computed(() => songTypeToDisplayName(item.type));

function goToItem(): void {
	switch (item.kind) {
		case "song":
		case "songPreview":
			navigation.goToSong(item);
			return;
		case "album":
		case "albumPreview":
			navigation.goToAlbum(item);
			return;
		case "artist":
		case "artistPreview":
			navigation.goToArtist(item);
			return;
		case "playlist":
		case "playlistPreview":
			navigation.goToPlaylist(item);
			return;
	}
}

const contextMenuOpen = ref(false);
</script>

<template>
	<ContextMenu
		position="top"
		:class="$props.class"
		ref="contextMenu"
		@visibilitychange="contextMenuOpen = $event"
	>
		<ion-card
			button
			class="search-result-card"
			@click="goToItem"
			:detail="contextMenuOpen"
			:class="$attrs.class"
			:style="$attrs.style"
		>
			<LocalImg
				size="large"
				:src="item.artwork"
				:alt="`Artwork for ${item.kind} '${item.title}'`"
				:class="{ [item.kind]: true }"
			/>

			<ion-card-header>
				<ion-card-title class="ion-text-nowrap">
					{{ item.title }}
				</ion-card-title>
				<ion-card-subtitle class="ion-text-nowrap">
					<span v-if="item.type">
						<ion-icon :icon="compassIcon" />
						{{ displayName }}
					</span>

					{{ formattedArtists }}
				</ion-card-subtitle>
			</ion-card-header>
		</ion-card>

		<template #options>
			<slot name="options">
				<template v-if="item.kind === 'album' || item.kind === 'albumPreview'">
					<ion-item :button="true" :detail="false" @click="musicPlayer.playAlbumNow(item)">
						<ion-icon aria-hidden="true" :icon="playIcon" slot="end" />
						Play now
					</ion-item>

					<ion-item :button="true" :detail="false" @click="musicPlayer.playAlbumNext(item)">
						<ion-icon aria-hidden="true" :icon="hourglassIcon" slot="end" />
						Play next
					</ion-item>

					<ion-item :button="true" :detail="false" @click="musicPlayer.playAlbumLast(item)">
						<ion-icon aria-hidden="true" :icon="addIcon" slot="end" />
						Add to queue
					</ion-item>

					<ion-item-divider />

					<ion-item
						data-instant-close
						:button="true"
						:detail="false"
						@click="openAddToPlaylistModal(item)"
					>
						<ion-icon aria-hidden="true" :icon="playlistAddIcon" slot="end" />
						Add to playlist
					</ion-item>
				</template>

				<template v-if="item.kind === 'song' || item.kind === 'songPreview'">
					<ion-item :button="true" :detail="false" @click="musicPlayer.playSongNow(item)">
						<ion-icon aria-hidden="true" :icon="playIcon" slot="end" />
						Play now
					</ion-item>

					<ion-item :button="true" :detail="false" @click="musicPlayer.playSongNext(item)">
						<ion-icon aria-hidden="true" :icon="hourglassIcon" slot="end" />
						Play next
					</ion-item>

					<ion-item :button="true" :detail="false" @click="musicPlayer.playSongLast(item)">
						<ion-icon aria-hidden="true" :icon="addIcon" slot="end" />
						Add to queue
					</ion-item>

					<ion-item-divider />

					<ion-item
						data-instant-close
						:button="true"
						:detail="false"
						@click="openAddToPlaylistModal(item)"
					>
						<ion-icon aria-hidden="true" :icon="playlistAddIcon" slot="end" />
						Add to playlist
					</ion-item>
				</template>
			</slot>
		</template>
	</ContextMenu>
</template>

<style scoped>
.context-menu-item .search-result-card {
	width: 100%;
}

.context-menu {
	:global(&:has(.search-result-card)) {
		--move-item-width: min(80vw, 400px);
		--move-item-height: calc(var(--move-item-width) * 1.165);
	}

	&.opened .search-result-card {
		background: var(--ion-background-color-step-100, #fff);
		--border-color: transparent;

		border-radius: 24px;
		padding: 12px;

		& > .local-img {
			border-radius: 12px;

			&.artist {
				border-radius: 9999px;
			}

			&.album {
				border-radius: 24px;
			}

			border: 1px solid #0002;
		}
	}
}

.search-result-card {
	margin: 0;
	background: transparent;
	box-shadow: none;
	border-radius: 0;

	user-select: none;
	-webkit-user-drag: none;

	& > .local-img {
		border-radius: 8px;
		border: 0.55px solid #0002;
		width: 100%;
		--img-width: 100%;
	}

	& > ion-card-header {
		padding: 8px;

		& > ion-card-title {
			font-size: 1rem;
			font-weight: 550;
			text-overflow: ellipsis;
			overflow: hidden;
		}

		& > ion-card-subtitle {
			font-size: 0.75rem;
			font-weight: 400;
			text-overflow: ellipsis;
			overflow: hidden;
		}
	}
}
</style>
