<script lang="ts" setup>
import { Album, AlbumPreview } from "@/services/Music/objects";

import GenericAlbumItem from "@/components/GenericAlbumItem.vue";

type SearchResult = Album | AlbumPreview;
const { searchResult } = defineProps<{ searchResult: SearchResult }>();
</script>

<template>
	<GenericAlbumItem
		:album="searchResult"
		:title="searchResult.title"
		:kind="searchResult.kind"
		:type="searchResult.type"
		:artwork="searchResult.artwork"
		:router-link="`/items/albums/album/${searchResult.type}/${searchResult.id}`"
	/>
</template>
