<script lang="ts" setup>
import {
	IonBackButton,
	IonButton,
	IonButtons,
	IonContent,
	IonHeader,
	IonIcon,
	IonPage,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";
import { personCircle as personIcon } from "ionicons/icons";

import { createSettingsModal } from "@/components/AppSettingsModal.vue";
import { computed, onUpdated } from "vue";

const { title, backButton } = defineProps<{
	title?: string;
	backButton?: string;
}>();

const slots = defineSlots<{
	default(): any;

	"toolbar"(): any;
	"toolbar-leading"(): any;
	"toolbar-start"(): any;
	"toolbar-end"(): any;
	"toolbar-trailing"(): any;

	"header-leading"(): any;
	"header-trailing"(): any;
}>();

const inlineView = computed(() => !(slots["toolbar-start"] || backButton));

async function openSettings(): Promise<void> {
	const modal = await createSettingsModal();
	await modal.present();
	await modal.onDidDismiss();
}
</script>

<template>
	<ion-page>
		<ion-header translucent>
			<slot name="header-leading" />

			<slot name="toolbar">
				<ion-toolbar>
					<div slot="start">
						<slot name="toolbar-start">
							<ion-buttons v-if="backButton">
								<ion-back-button :text="backButton" />
							</ion-buttons>
						</slot>
					</div>

					<ion-title v-if="title">{{ title }}</ion-title>

					<div v-if="!inlineView" slot="end">
						<slot name="toolbar-end">
							<ion-buttons slot="end">
								<ion-button @click="openSettings">
									<ion-icon size="large" slot="icon-only" :icon="personIcon" />
								</ion-button>
							</ion-buttons>
						</slot>
					</div>
				</ion-toolbar>

				<slot name="header-trailing" />
			</slot>
		</ion-header>

		<ion-content fullscreen>
			<ion-header v-if="title" collapse="condense">
				<slot name="header-leading" />

				<slot name="toolbar">
					<ion-toolbar>
						<slot name="toolbar-leading" />

						<ion-title size="large">{{ title }}</ion-title>

						<div v-if="inlineView" slot="end">
							<slot name="toolbar-end">
								<ion-buttons slot="end">
									<ion-button @click="openSettings">
										<ion-icon size="large" slot="icon-only" :icon="personIcon" />
									</ion-button>
								</ion-buttons>
							</slot>
						</div>

						<slot name="toolbar-trailing" />
					</ion-toolbar>
				</slot>

				<slot name="header-trailing" />
			</ion-header>

			<slot />
		</ion-content>
	</ion-page>
</template>

<style scoped>
ion-back-button {
	display: block;
}
</style>
