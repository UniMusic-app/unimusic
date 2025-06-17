<script setup lang="ts">
import {
	IonAccordion,
	IonAccordionGroup,
	IonButton,
	IonContent,
	IonHeader,
	IonIcon,
	IonItem,
	IonLabel,
	IonList,
	IonNote,
	IonReorder,
	IonReorderGroup,
	IonSpinner,
	IonTitle,
	IonToggle,
	IonToolbar,
	ItemReorderCustomEvent,
} from "@ionic/vue";

import {
	// @ts-ignore it actually exists
	readerOutline as lyricsServicesIcon,
	musicalNotes as musicServicesIcon,
	syncOutline as syncIcon,
} from "ionicons/icons";

import AppPage from "@/components/AppPage.vue";
import { useLyricsServices } from "@/stores/lyrics-services";
import { computed, ref } from "vue";

const services = useLyricsServices();

const props = defineProps<{ nav: HTMLIonNavElement }>();
const nav = props.nav;

const forceUpdate = ref(0);
const sortedServices = computed(() => {
	forceUpdate.value;
	const registeredServices = services.registeredServices;
	return Object.values(registeredServices).sort((a, b) => {
		if (a.available && !b.available) return -1;
		return a.order.value - b.order.value || a.name.localeCompare(b.name);
	});
});

async function reorderServices(event: ItemReorderCustomEvent): Promise<void> {
	const { from, to } = event.detail;
	const serviceFrom = sortedServices.value[from]!;
	const serviceTo = sortedServices.value[to]!;

	serviceFrom.reorder(serviceTo.order.value + (from > to ? -1 : 1));
	forceUpdate.value += 1;

	await event.detail.complete();
}
</script>

<template>
	<AppPage
		title="Sync"
		back-button="Settings"
		:show-content-header="false"
		:force-inline-view="false"
	>
		<ion-content id="music-services-page-content" class="ion-padding">
			<header>
				<ion-icon :icon="lyricsServicesIcon" color="primary" />
				<ion-header collapse="condense">
					<ion-toolbar>
						<ion-title class="ion-text-nowrap" size="large">Lyrics Services</ion-title>
					</ion-toolbar>
				</ion-header>
				<ion-note>Lyrics Services allow you to view lyrics alongside listening to the song.</ion-note>
			</header>

			<ion-list inset>
				<ion-reorder-group :disabled="false" @ion-item-reorder="reorderServices">
					<ion-item v-for="service in sortedServices" :key="service.name" :disabled="!service.available">
						<ion-label>
							<span>{{ service.name }}</span>
							<p>{{ service.description }}</p>
						</ion-label>

						<ion-toggle
							slot="end"
							:checked="service.enabled.value"
							@ion-change="service.enabled.value = !service.enabled.value"
						/>

						<ion-reorder slot="end" />
					</ion-item>
				</ion-reorder-group>
			</ion-list>
			<ion-note class="ion-padding-horizontal">
				Order of Lyrics Services determines which ones will be fetched first.
			</ion-note>
		</ion-content>
	</AppPage>
</template>

<style scoped>
#music-services-page-content {
	& > header {
		text-align: center;
		margin-inline: auto;
		margin-bottom: 16px;

		& > ion-icon {
			font-size: 4rem;
			width: 100%;
		}

		& > ion-header {
			margin-inline: auto;
			width: max-content;
		}

		& ion-title {
			transform-origin: top center;
			margin: 0;
		}

		& > ion-note {
			display: inline-block;
			text-wrap: balance;
		}
	}

	& > ion-list {
		& ion-item {
			--background: var(--ion-background-color-step-150, #ebebeb);
		}

		& ion-reorder {
			margin-left: 8px;
		}
	}
}
</style>
