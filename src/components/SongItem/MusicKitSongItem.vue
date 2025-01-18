<template>
	<song-item :artwork-url :artist :title @play="play" @add-to-queue="addToQueue" />
</template>

<script setup lang="ts">
import { ref } from "vue";
import SongItem from "@/components/SongItem.vue";
import { useMusicKit } from "@/stores/musickit";
import { useMusicPlayer } from "@/stores/music-player";
import { MusicKitSong } from "@/types/music-player";

const { song } = defineProps<{ song: MusicKit.Songs }>();

const title = song.attributes?.name;
const artist = song.attributes?.artistName;
const artworkUrl = ref<string>();
if (song.attributes) {
	const musicKit = useMusicKit();
	musicKit.withMusic(() => {
		artworkUrl.value = MusicKit.formatArtworkURL(song.attributes!.artwork, 256, 256);
	});
}

const musicPlayer = useMusicPlayer();

function musicKitSong(): MusicKitSong {
	return {
		type: "musickit",

		id: song.id,
		title,
		artist,
		artworkUrl: artworkUrl.value,

		data: song,
	};
}

function play(): void {
	musicPlayer.add(musicKitSong(), musicPlayer.queueIndex);
	musicPlayer.play();
}

function addToQueue(): void {
	musicPlayer.add(musicKitSong());
}
</script>
