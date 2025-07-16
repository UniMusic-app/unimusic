<script lang="ts" setup>
import { SearchResultItem } from "@/services/Music/MusicService";
import GenericAlbumItem from "./GenericAlbumItem.vue";
import GenericArtistItem from "./GenericArtistItem.vue";
import GenericSongItem from "./GenericSongItem.vue";

const { item } = defineProps<{ item: SearchResultItem }>();
</script>

<template>
	<GenericSongItem
		v-if="item.kind === 'song' || item.kind === 'songPreview'"
		:song="item"
		:title="item.title"
		:artwork="item.artwork"
		:artists="item.artists"
		:album="item.album"
	/>
	<GenericAlbumItem
		v-else-if="item.kind === 'album' || item.kind === 'albumPreview'"
		:album="item"
		:title="item.title"
		:artwork="item.artwork"
	/>
	<GenericArtistItem
		v-else-if="item.kind === 'artist' || item.kind === 'artistPreview'"
		:title="item.title"
		:artwork="item.artwork"
	/>
</template>
