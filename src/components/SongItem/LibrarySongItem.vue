<template>
	<song-item :artwork-url :artist :title @play="play" @add-to-queue="addToQueue" />
</template>

<script setup lang="ts">
import SongItem from "@/components/SongItem.vue";
import { useMusicPlayer } from "@/stores/music-player";
import { AudioLibrarySong } from "@/plugins/AudioLibrary";
import { LibrarySong } from "@/types/music-player";

const { song } = defineProps<{ song: AudioLibrarySong }>();

const { title, artist } = song;
const artworkUrl = song.artwork;
const musicPlayer = useMusicPlayer();

function librarySong(): LibrarySong {
	return {
		type: "library",

		id: song.id,
		title,
		artist,
		artworkUrl,

		data: song,
	};
}

function play(): void {
	musicPlayer.add(librarySong(), musicPlayer.queueIndex);
	musicPlayer.play();
}

function addToQueue(): void {
	musicPlayer.add(librarySong());
}
</script>
