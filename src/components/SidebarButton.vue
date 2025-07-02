<script setup lang="ts">
import {
	createAnimation,
	getIonPageElement,
	IonIcon,
	IonItem,
	TransitionOptions,
} from "@ionic/vue";
import { computed } from "vue";
import { useRoute } from "vue-router";

const { icon, outlineIcon, href } = defineProps<{
	icon: string;
	outlineIcon: string;
	href: string;
}>();

const route = useRoute();

const active = computed(() => route.path.startsWith(href));

// modified mdTransitionAnimation
const fadeTransitionAnimation = (_: HTMLElement, options: TransitionOptions) => {
	const backDirection = options.direction === "back";
	const { enteringEl, leavingEl } = options;

	const ionPageElement = getIonPageElement(enteringEl);
	const enteringToolbarEle = ionPageElement.querySelector("ion-toolbar");
	const rootTransition = createAnimation();

	rootTransition.addElement(ionPageElement).fill("both").beforeRemoveClass("ion-page-invisible");

	// animate the component itself
	if (backDirection) {
		rootTransition
			.duration((options.duration ?? 0) || 200)
			.easing("cubic-bezier(0.47,0,0.745,0.715)");
	} else {
		rootTransition
			.duration((options.duration ?? 0) || 280)
			.easing("cubic-bezier(0.36,0.66,0.04,1)")
			.fromTo("scale", "98%", "100%")
			.fromTo("opacity", 0.01, 1);
	}

	// Animate toolbar if it's there
	if (enteringToolbarEle) {
		const enteringToolBar = createAnimation();
		enteringToolBar.addElement(enteringToolbarEle);
		rootTransition.addAnimation(enteringToolBar);
	}

	// setup leaving view
	if (leavingEl && backDirection) {
		// leaving content
		rootTransition
			.duration((options.duration ?? 0) || 200)
			.easing("cubic-bezier(0.47,0,0.745,0.715)");

		const leavingPage = createAnimation();
		leavingPage
			.addElement(getIonPageElement(leavingEl))
			.onFinish((currentStep) => {
				if (currentStep === 1 && leavingPage.elements.length > 0) {
					leavingPage.elements[0]!.style.setProperty("display", "none");
				}
			})
			.fromTo("scale", "100%", "98%")
			.fromTo("opacity", 1, 0);

		rootTransition.addAnimation(leavingPage);
	}

	return rootTransition;
};
</script>

<template>
	<ion-item
		:class="{ active }"
		:router-link="href"
		:detail="false"
		:router-animation="fadeTransitionAnimation"
	>
		<ion-icon color="primary" aria-hidden="true" slot="start" :icon="active ? icon : outlineIcon" />
		<slot />
	</ion-item>
</template>
