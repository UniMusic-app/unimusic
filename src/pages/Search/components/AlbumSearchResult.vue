<script lang="ts" setup>
import GenericAlbumItem from "@/components/GenericAlbumItem.vue";
import { Album, AlbumPreview } from "@/services/Music/objects";

type SearchResult = Album | AlbumPreview;
const { searchResult } = defineProps<{ searchResult: SearchResult }>();
</script>

<template>
	<GenericAlbumItem
		:title="searchResult.title"
		:kind="searchResult.kind"
		:type="searchResult.type"
		:artwork="searchResult.artwork"
		:router-link="`/items/albums/album/${searchResult.type}/${searchResult.id}`"
	>
		<template #options>
			<!-- TODO: Play album etc-->
		</template>
	</GenericAlbumItem>
</template>
