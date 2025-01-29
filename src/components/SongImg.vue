<template>
	<ion-img v-if="lazy" :src="url" :alt />
	<img v-else :src="url" :alt />
</template>

<script setup lang="ts">
import { useLocalImages } from "@/stores/local-images";
import { SongImage } from "@/stores/music-player";
import { IonImg } from "@ionic/vue";
import { ref } from "vue";

const localImages = useLocalImages();
const {
	lazy = false,
	src,
	alt,
} = defineProps<{ lazy?: boolean; src: SongImage | undefined; alt?: string }>();

const url = ref<string>();
localImages.getSongImageUrl(src).then((songUrl) => {
	url.value = songUrl;
});
</script>
