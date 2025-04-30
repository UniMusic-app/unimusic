<script lang="ts" setup>
import GenericSongItem from "@/components/GenericSongItem.vue";
import { Song, SongPreview } from "@/services/Music/objects";
import { useMusicPlayer } from "@/stores/music-player";
import { useNavigation } from "@/stores/navigation";

const musicPlayer = useMusicPlayer();
const navigation = useNavigation();

type SearchResult = Song | SongPreview;
const { searchResult } = defineProps<{
	searchResult: SearchResult;
}>();
</script>

<template>
	<GenericSongItem
		:song="searchResult"
		:title="searchResult.title"
		:kind="searchResult.kind"
		:artists="searchResult.artists"
		:artwork="searchResult.artwork"
		:type="searchResult.type"
		@item-click="musicPlayer.playSongNow(searchResult)"
		@context-menu-click="navigation.goToSong(searchResult)"
	/>
</template>
