<script lang="ts" setup>
import { useElementSize } from "@vueuse/core";
import { computed, useTemplateRef } from "vue";

const wrapper = useTemplateRef("wrapper");
const element = useTemplateRef("wrapping-element");

const { text } = defineProps<{ text: string }>();

const wrapperSize = useElementSize(wrapper);
const elementSize = useElementSize(element);

const shouldWrap = computed(() => {
	return wrapperSize.width.value < elementSize.width.value;
});
</script>

<template>
	<div ref="wrapper" class="wrapping-marquee" :class="{ wrapping: shouldWrap }" :key="text">
		<span ref="wrapping-element" :class="{ initial: shouldWrap }">{{ text }}</span>
		<span v-if="shouldWrap" class="following">{{ text }}</span>
	</div>
</template>

<style scoped>
@keyframes initial-marquee {
	from {
		transform: translateX(100%);
	}

	to {
		transform: translateX(-100%);
	}
}

@keyframes wrapping-marquee {
	from {
		transform: translateX(0%);
	}

	to {
		transform: translateX(-200%);
	}
}

.wrapping-marquee {
	position: relative;
	display: inline-flex;
	width: 100%;
	font-size: inherit;
	font-weight: inherit;

	--duration: var(--marquee-duration, 10s);
	--gap: var(--marquee-gap, 0.5rem);

	& > .initial,
	& > .following {
		font-size: inherit;
		font-weight: inherit;
		padding-inline: var(--gap);
	}

	& > .initial {
		animation:
			wrapping-marquee var(--duration) linear,
			initial-marquee var(--duration) calc(var(--duration) / 2) linear infinite;
	}

	& > .following {
		animation: wrapping-marquee var(--duration) linear infinite;
	}
}
</style>
