<script lang="ts" setup>
import { onLongPress } from "@vueuse/core";
import { nextTick, reactive, ref, useTemplateRef, watch } from "vue";

import { isMobilePlatform } from "@/utils/os";
import { sleep } from "@/utils/time";
import { Maybe } from "@/utils/types";
import { Haptics, ImpactStyle } from "@capacitor/haptics";
import { IonList } from "@ionic/vue";
import { useRoute } from "vue-router";

const route = useRoute();

const contextMenu = useTemplateRef("contextMenu");
const contextMenuItem = useTemplateRef("contextMenuItem");
const contextMenuOptions = useTemplateRef("contextMenuOptions");
const contextMenuPreview = useTemplateRef("contextMenuPreview");

const slots = defineSlots<{
	default(): any;
	options(): any;
	preview(): any;
}>();

const emit = defineEmits<{
	visibilitychange: [value: boolean];
}>();

const {
	event = "contextmenu",
	haptics = true,
	move = true,
	backdrop = true,
	position = "auto",
	disabled = false,
} = defineProps<{
	event?: "click" | "contextmenu";
	position?: "auto" | "top" | "bottom";
	move?: boolean;
	backdrop?: boolean;
	haptics?: boolean;
	disabled?: boolean;
}>();

if (isMobilePlatform() && event === "contextmenu") {
	onLongPress(
		contextMenuItem,
		async (event) => {
			if (event.target instanceof HTMLElement) {
				if ("contextMenuIgnore" in event.target.dataset || !event.target.matches(":hover")) {
					return;
				}
			}
			await openContextMenu();
		},
		{ delay: 200, modifiers: { prevent: true } },
	);
}

const state = ref<"closed" | "closing" | "opening" | "opened">("closed");

const initialStyle = {
	"--item-top": "auto",
	"--item-max-top": "auto",
	"--item-bottom": "auto",
	"--item-min-bottom": "auto",
	"--item-max-bottom": "auto",
	"--item-left": "auto",
	"--item-right": "auto",
	"--item-width": "auto",
	"--item-height": "auto",
	"--item-max-height": "auto",

	"--flex-direction": "column",
	"--flex-align": "start",
	"--direction-y": "top",
	"--direction-x": "left",

	"--options-height": "auto",
};

const style = reactive({ ...initialStyle });

function resetStyle(): void {
	Object.assign(style, initialStyle);
}

async function openContextMenu(): Promise<void> {
	if (disabled) return;

	if (haptics) {
		await Haptics.impact({ style: ImpactStyle.Heavy }).catch(() => {});
		await sleep(90);
	}

	state.value = "opening";
	await nextTick();

	let $contextMenu = contextMenu.value;
	let $contextMenuItem = contextMenuItem.value;
	let $contextMenuPreview = contextMenuPreview.value;
	let $contextMenuOptions = contextMenuOptions.value?.$el as Maybe<HTMLElement>;
	if (!$contextMenu || !$contextMenuItem) return;

	const itemRect = $contextMenuItem.getBoundingClientRect();

	const optionsChildren = $contextMenuOptions?.children?.length ?? 0;
	const approximateOptionsHeight = `${optionsChildren > 0 ? optionsChildren * 44 + 8 : 0}px`;

	// We first reset all styles and recalculate what's appropriate now
	resetStyle();

	let itemTop = itemRect.top;
	if (!move) {
		itemTop += itemRect.height;
	}
	style["--item-top"] = `${itemTop}px`;
	style["--item-max-top"] =
		`calc(100vh - var(--move-item-height, ${itemRect.height}px) - ${approximateOptionsHeight} - var(--ion-safe-area-bottom))`;

	style["--item-left"] = `${itemRect.left}px`;
	style["--item-width"] = `${itemRect.width}px`;
	style["--item-height"] = `${itemRect.height}px`;
	style["--item-max-height"] = move ? "var(--move-item-height)" : style["--item-height"];
	style["--options-height"] = approximateOptionsHeight;

	let directionY = "top";
	let directionX = "left";

	if (itemRect.left > window.innerWidth / 2) {
		style["--item-left"] = "auto";
		style["--item-right"] = `${window.innerWidth - itemRect.right}px`;
		style["--flex-align"] = "end";

		directionX = "right";
	}

	if (position === "bottom" || (position === "auto" && itemRect.top > window.innerHeight / 2)) {
		let itemBottom = Math.max(window.innerHeight - itemRect.bottom, 0);
		if (!move) {
			itemBottom += itemRect.height;
		}

		style["--item-bottom"] = `${itemBottom}px`;
		style["--item-min-bottom"] = `var(--ion-safe-area-bottom)`;
		style["--item-max-bottom"] =
			`calc(${window.innerHeight - itemRect.height}px - ${approximateOptionsHeight})`;

		style["--item-top"] = "auto";
		style["--item-max-top"] = "auto";

		style["--flex-direction"] = "column-reverse";

		directionY = "bottom";
	}

	style["--direction-x"] = directionX;
	style["--direction-y"] = directionY;

	// Because we want to use those styles as initial position, we re-open the modal again
	state.value = "closed";
	await nextTick();
	state.value = "opening";
	await nextTick();

	$contextMenu = contextMenu.value;
	$contextMenuItem = contextMenuItem.value;
	$contextMenuPreview = contextMenuPreview.value;
	$contextMenuOptions = contextMenuOptions.value?.$el as Maybe<HTMLElement>;
	if (!$contextMenu || !$contextMenuItem) return;

	// Adjust the height post-mortem to be accurate
	if (move) {
		$contextMenu.addEventListener(
			"transitionend",
			() => (style["--item-max-height"] = `${$contextMenuPreview?.firstElementChild?.clientHeight}px`),
			{ once: true },
		);
	}

	// NOTE: This 2 frame delay is required to properly work on WebKit
	requestAnimationFrame(() => (state.value = "opened"));
	$contextMenu.showPopover();
	emit("visibilitychange", true);
}

function closeContextMenu(event?: MouseEvent): void {
	if (state.value === "closed") {
		return;
	}

	if (event && "instantClose" in (event.target as HTMLElement).dataset) {
		state.value = "closed";
	} else {
		state.value = "closing";
	}

	emit("visibilitychange", false);
}

function immediatelyCloseContextMenu(): void {
	state.value = "closed";
	resetStyle();
	emit("visibilitychange", false);
}

async function toggleContextMenu(): Promise<void> {
	switch (state.value) {
		case "opening":
		case "opened":
			closeContextMenu();
			break;
		case "closing":
		case "closed":
			await openContextMenu();
			break;
	}
}

// Immediately close ContextMenu on route change
watch(
	() => route.fullPath,
	() => immediatelyCloseContextMenu(),
);
</script>

<template>
	<span @[event].prevent="toggleContextMenu" ref="contextMenuItem" class="context-menu-item">
		<slot />
	</span>

	<div
		v-if="state !== 'closed'"
		ref="contextMenu"
		popover="manual"
		class="context-menu"
		:class="{ [state]: true, move, backdrop, [style['--direction-x']]: true }"
		:style
		@click="closeContextMenu($event)"
	>
		<div class="backdrop" />

		<div
			class="preview-container"
			@transitionend.self="state === 'closing' && immediatelyCloseContextMenu()"
		>
			<div v-if="move" class="preview" ref="contextMenuPreview">
				<slot name="preview">
					<slot />
				</slot>
			</div>

			<ion-list ref="contextMenuOptions" v-if="slots.options" class="options" inset>
				<slot name="options" />
			</ion-list>
		</div>
	</div>
</template>

<style>
/** Zoom out animation when context menu is opened */
@media screen and (max-width: 640px) {
	ion-app {
		&:has(> ion-modal) {
			& > ion-modal .ion-page {
				&:has(.context-menu.move.opened) {
					transition: transform 250ms ease-out;
					transform: scale(95%);
				}

				&:has(.context-menu.move:not(.opened)) {
					transition: transform 250ms ease-out;
					transform: scale(100%);
				}
			}
		}

		&:not(:has(> ion-modal)) {
			&:has(.context-menu.move.opened) {
				transition: transform 250ms ease-out;
				transform: scale(91.5%);
			}

			&:has(.context-menu.move:not(.opened)) {
				transition: transform 250ms ease-out;
				transform: scale(100%);
			}
		}
	}
}

.context-menu-item {
	display: block;
	content-visibility: auto;

	&:has(+ .context-menu.move:not(.closed)) {
		visibility: hidden;
	}
}

.context-menu {
	--transition-duration: 350ms;
	--transition-easing: cubic-bezier(0.175, 0.885, 0.32, 1.075);

	position: fixed;
	top: 0;
	left: 0;
	width: 100%;
	height: 100%;

	padding: 0;
	margin: 0;
	background-color: transparent;

	overflow: hidden;
	border: none;

	/**
	 * Popovers backdrop is a pain in the ass:
	 * - animations dont work on some browsers
	 * - its click through, even when pointer-events: full is set
	 */
	&::backdrop {
		display: none;
	}
	& > .backdrop {
		content: "";

		position: fixed;
		top: 0;
		left: 0;
		width: 100vw;
		height: 100vh;

		transition:
			backdrop-filter,
			background-color,
			var(--transition-duration) var(--transition-easing);
	}

	&.backdrop.opened > .backdrop {
		@media screen and (max-width: 640px) {
			backdrop-filter: blur(12px);
		}
		background-color: rgba(0, 0, 0, 0.2);
	}

	--options-width: min(400px, 70vw);
	--move-item-width: min(500px, 90vw);

	& .preview-container {
		transition:
			top,
			left,
			width,
			height,
			var(--transition-duration) var(--transition-easing);

		position: fixed;
		top: var(--item-top);
		bottom: var(--item-bottom);
		left: var(--item-left);
		right: var(--item-right);
		width: 100%;
		height: 100%;

		display: flex;
		flex-direction: var(--flex-direction);
		align-items: var(--flex-align);
	}

	&.opened .preview-container {
		/* Add tiny offset to always trigger transitionend event */
		bottom: clamp(var(--item-min-bottom), calc(var(--item-bottom) + 0.001px), var(--item-max-bottom));
		top: clamp(
			var(--ion-safe-area-top),
			calc(var(--item-top) - (var(--item-height) / 2) + 0.001px),
			var(--item-max-top)
		);
	}

	@media screen and (max-width: 640px) {
		&.opened.move .preview-container {
			top: clamp(
				calc(var(--ion-safe-area-top) + 8px),
				calc(var(--item-top) - var(--options-height)),
				var(--item-max-top)
			);
			bottom: clamp(var(--item-min-bottom), var(--item-bottom), var(--item-max-bottom));
		}
		&.opened.move.left .preview-container {
			left: clamp(
				8px,
				calc((100vw - var(--move-item-width)) / 2),
				calc(100vw - var(--move-item-width))
			);
		}
		&.opened.move.right .preview-container {
			right: clamp(
				8px,
				calc((100vw - var(--move-item-width)) / 2),
				calc(100vw - var(--move-item-width))
			);
		}
	}

	& .preview {
		transition:
			width,
			height,
			filter,
			var(--transition-duration) var(--transition-easing);
		display: flex;
		flex-direction: column;

		interpolate-size: allow-keywords;

		width: var(--item-width);
		height: var(--item-height);
		max-height: var(--item-max-height);
	}
	&.closed.move .preview {
		width: var(--item-width);
		height: var(--item-height);
	}
	&.opened .preview {
		filter: drop-shadow(0 0 16px #0004);
	}
	&.opened.move .preview {
		width: var(--move-item-width);
		height: var(--move-item-height, max-content);
	}

	& .options {
		margin: 0;
		margin-block: 8px;
		width: var(--options-width);

		transition:
			opacity,
			transform,
			filter,
			var(--transition-duration) var(--transition-easing);
		transform-origin: var(--direction-y) var(--direction-x);
		transform: scale(0%);
		opacity: 30%;

		background-color: transparent;
		backdrop-filter: blur(6px) saturate(200%);

		filter: drop-shadow(0 0 16px #0004);

		& > ion-item {
			opacity: 90%;

			--background: var(--ion-background-color-step-150, #eee);
			&:hover,
			&:focus {
				--background: var(--ion-background-color-step-250, #ddd);
			}

			ion-icon[slot="end"] {
				margin-left: 1rem;
			}
		}

		& > ion-item-divider {
			opacity: 90%;
			min-height: 6px;
			--background: var(--ion-background-color-step-200, #ccc);
			outline: 0.02px solid var(--ion-background-color-step-200);
		}
	}
	&.opened .options {
		transform: scale(100%);
		opacity: 100%;
	}
}
</style>
