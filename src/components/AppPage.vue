<script lang="ts" setup>
import {
	IonBackButton,
	IonButtons,
	IonContent,
	IonHeader,
	IonPage,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";

const {
	title,
	backButton,
	showPageHeader = true,
	showContentHeader = true,
	class: _class,
} = defineProps<{
	title?: string;
	backButton?: string;
	showPageHeader?: boolean;
	showContentHeader?: boolean;
	class?: string;
}>();

defineSlots<{
	default(): any;

	"toolbar"(): any;
	"toolbar-leading"(): any;
	"toolbar-start"(): any;
	"toolbar-end"(): any;
	"toolbar-trailing"(): any;

	"header-leading"(): any;
	"header-trailing"(): any;
}>();
</script>

<template>
	<ion-page id="app-page" :class="_class">
		<Transition name="slide">
			<ion-header v-if="showPageHeader" translucent>
				<slot name="header-leading" />

				<slot name="toolbar">
					<ion-toolbar>
						<div slot="start">
							<slot name="toolbar-start">
								<ion-buttons v-if="backButton !== undefined">
									<ion-back-button :text="backButton" />
								</ion-buttons>
							</slot>
						</div>

						<div slot="end">
							<slot name="toolbar-end" />
						</div>
					</ion-toolbar>

					<slot name="header-trailing" />
				</slot>
			</ion-header>
		</Transition>

		<ion-content fullscreen>
			<Transition name="slide">
				<ion-header v-if="showContentHeader && title" collapse="condense">
					<slot name="header-leading" />

					<slot name="toolbar">
						<ion-toolbar>
							<slot name="toolbar-leading" />

							<ion-title size="large">{{ title }}</ion-title>

							<div slot="end">
								<slot name="toolbar-end" />
							</div>

							<slot name="toolbar-trailing" />
						</ion-toolbar>
					</slot>

					<slot name="header-trailing" />
				</ion-header>
			</Transition>

			<slot />
		</ion-content>
	</ion-page>
</template>

<style scoped>
@keyframes show-header {
	from {
		height: 0;
	}

	to {
		height: var(--header-height);
	}
}

.slide-enter-active {
	animation: show-header 150ms cubic-bezier(0.32, 0.885, 0.55, 1.175) forwards;
}

.slide-leave-active {
	animation: show-header 150ms cubic-bezier(0.175, 0.885, 0.32, 1.075) reverse forwards;
}

ion-back-button {
	display: block;
}
</style>
