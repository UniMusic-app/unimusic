<script lang="ts" setup>
import { Artist, ArtistPreview } from "@/services/Music/objects";

import GenericArtistItem from "@/components/GenericArtistItem.vue";

type SearchResult = Artist | ArtistPreview;
const { searchResult } = defineProps<{ searchResult: SearchResult }>();
</script>

<template>
	<GenericArtistItem
		:title="searchResult.title"
		:kind="searchResult.kind"
		:type="searchResult.type"
		:artwork="searchResult.artwork"
		:router-link="`/items/artists/${searchResult.type}/${searchResult.id}`"
	/>
</template>
