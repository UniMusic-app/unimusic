<template>
	<ion-img v-if="lazy" :src="url ?? EMPTY_IMAGE" :alt :class="`song-img ${$props.class ?? ''}`" />
	<img v-else :src="url ?? EMPTY_IMAGE" :alt :class="`song-img ${$props.class ?? ''}`" />
</template>

<script setup lang="ts">
import { ref, watchEffect } from "vue";

import { IonImg } from "@ionic/vue";

import { useLocalImages } from "@/stores/local-images";
import { SongImage } from "@/stores/music-player";

const EMPTY_IMAGE =
	"data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";

const localImages = useLocalImages();
interface Props {
	lazy?: boolean;
	size?: "small" | "medium" | "large";
	src: SongImage | undefined;
	alt?: string;
}
const { lazy = false, src, alt } = defineProps<Props>();

const url = ref<string>();
watchEffect(async () => {
	url.value = await localImages.getSongImageUrl(src);
});
</script>

<style>
.song-img {
	position: relative;
	border-radius: var(--img-border-radius, inherit);
	width: var(--img-width, auto);
	height: var(--img-height, auto);
}
</style>
