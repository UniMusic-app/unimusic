<script setup lang="ts">
import { computed } from "vue";

import { LocalImage, useLocalImages } from "@/stores/local-images";

const localImages = useLocalImages();
const { src, alt } = defineProps<{
	src?: LocalImage;
	alt?: string;
}>();

const url = computed(() => localImages.getUrl(src));
</script>

<template>
	<img :src="url" :alt :class="`song-img ${$props.class ?? ''}`" />
</template>

<style>
.song-img {
	position: relative;
	border-radius: var(--img-border-radius, inherit);
	width: var(--img-width, auto);
	height: var(--img-height, auto);
}
</style>
