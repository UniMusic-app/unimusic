<script setup lang="ts">
import { computed, ref } from "vue";

import { IonIcon } from "@ionic/vue";

import { LocalImage, LocalImageSize, useLocalImages } from "@/stores/local-images";
import { watchAsync } from "@/utils/vue";

const localImages = useLocalImages();
const {
	src,
	size = "small",
	alt,
	fallbackIcon,
} = defineProps<{
	src?: LocalImage;
	size?: LocalImageSize;
	alt?: string;
	fallbackIcon?: string;
}>();

const url = ref<string>();
watchAsync(
	() => src,
	async (src) => {
		if (!src) return;
		url.value = await localImages.getUrl(src, size);
	},
	{ immediate: true },
);
const style = computed(() => src?.style ?? localImages.getStyle(src?.id));
const loaded = ref(false);
</script>

<template>
	<div :class="`local-img ${$props.class ?? ''}`">
		<img v-show="loaded" v-if="src && url" :src="url" :alt @load="loaded = true" />
		<Transition>
			<div v-if="!loaded" :style="{ '--bg-color': style?.bgColor }" class="fallback">
				<ion-icon v-if="fallbackIcon" :icon="fallbackIcon" />
			</div>
		</Transition>
	</div>
</template>

<style>
.v-enter-active,
.v-leave-active {
	position: absolute !important;
	transition: opacity 170ms ease;
}

.v-enter-from,
.v-leave-to {
	opacity: 0;
}

.local-img {
	position: relative;
	display: inline-flex;
	pointer-events: none;
	user-select: none;

	& > .fallback,
	& > img {
		position: relative;
		width: var(--img-width, inherit);
		max-width: var(--img-max-width, auto);
		height: var(--img-height, inherit);
		max-height: var(--img-max-height, auto);
		border-radius: var(--img-border-radius, inherit);
	}

	& > .fallback {
		background-color: var(--bg-color);
		aspect-ratio: 1 / 1;

		& > ion-icon {
			display: block;
			margin: auto;
			height: 100%;
			font-size: 1.5rem;
		}
	}
}

.context-menu:not(.closed) > .context-menu-item .local-img {
	& > .fallback {
		z-index: -1;
	}
}
</style>
