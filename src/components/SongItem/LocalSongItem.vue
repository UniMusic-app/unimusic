<template>
	<song-item :artwork-url :artist :title @play="play" @add-to-queue="addToQueue" />
</template>

<script setup lang="ts">
import SongItem from "@/components/SongItem.vue";
import { useMusicPlayer } from "@/stores/music-player";
import { LocalSong } from "@/types/music-player";
import { LocalMusicSong } from "@/plugins/LocalMusicPlugin";

const { song } = defineProps<{ song: LocalMusicSong }>();

const title = song.title;
const artist = song.artist;
const artworkUrl = song.artwork;

const musicPlayer = useMusicPlayer();

function localSong(): LocalSong {
	return {
		type: "local",

		id: song.id,
		title,
		artist,
		artworkUrl,

		data: song,
	};
}

function play(): void {
	musicPlayer.add(localSong(), musicPlayer.queueIndex);
	musicPlayer.play();
}

function addToQueue(): void {
	musicPlayer.add(localSong());
}
</script>
