<template>
	<song-item :artwork-url :song-artist :song-name @play="play" @add-to-queue="addToQueue" />
</template>

<script setup lang="ts">
import { ref } from "vue";
import SongItem from "@/components/SongItem.vue";
import { useMusicKit } from "@/stores/musickit";
import { useMusicPlayer } from "@/stores/music-player";

const { song } = defineProps<{ song: MusicKit.Songs }>();

const songName = song.attributes?.name ?? "Unknown song name";
const songArtist = song.attributes?.artistName ?? "Unknown artist";
const artworkUrl = ref("");

if (song.attributes) {
	const music = useMusicKit();
	music.withMusic(() => {
		artworkUrl.value = MusicKit.formatArtworkURL(song.attributes!.artwork, 256, 256);
	});
}

const musicPlayer = useMusicPlayer();

function play(): void {
	musicPlayer.add(
		{
			type: "musickit",

			id: song.id,
			name: songName,
			artist: songArtist,
			artworkUrl: artworkUrl.value,

			data: song,
		},
		musicPlayer.queueIndex,
	);
	musicPlayer.play();
}

function addToQueue(): void {
	musicPlayer.add({
		type: "musickit",

		id: song.id,
		name: songName,
		artist: songArtist,
		artworkUrl: artworkUrl.value,

		data: song,
	});
}
</script>
