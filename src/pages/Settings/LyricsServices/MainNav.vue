<script setup lang="ts">
import {
	IonButton,
	IonButtons,
	IonContent,
	IonHeader,
	IonIcon,
	IonItem,
	IonLabel,
	IonList,
	IonNote,
	IonReorder,
	IonReorderGroup,
	IonTitle,
	IonToggle,
	IonToolbar,
	ItemReorderCustomEvent,
} from "@ionic/vue";

import {
	// @ts-expect-error it actually exists
	readerOutline as lyricsServicesIcon,
} from "ionicons/icons";

import AppPage from "@/components/AppPage.vue";
import { useLyricsServices } from "@/stores/lyrics-services";
import { computed, ref } from "vue";

const services = useLyricsServices();

const reorder = ref(false);

const forceUpdate = ref(0);
const sortedServices = computed(() => {
	// eslint-disable-next-line @typescript-eslint/no-unused-expressions
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

	await serviceFrom.reorder(serviceTo.order.value + (from > to ? -1 : 1));
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
		<template #toolbar-end>
			<ion-buttons>
				<ion-button @click="reorder = !reorder" :strong="reorder">
					{{ reorder ? "Done" : "Reorder" }}
				</ion-button>
			</ion-buttons>
		</template>

		<ion-content id="lyrics-services-page-content" class="ion-padding">
			<header>
				<ion-icon :icon="lyricsServicesIcon" color="primary" />
				<ion-header collapse="condense">
					<ion-toolbar>
						<ion-title class="ion-text-nowrap" size="large">Lyrics</ion-title>
					</ion-toolbar>
				</ion-header>
				<ion-note>Lyrics Services allow you to view lyrics alongside listening to the song.</ion-note>
			</header>

			<template v-if="reorder">
				<ion-list inset>
					<ion-reorder-group :disabled="false" @ion-item-reorder="reorderServices">
						<ion-item
							v-for="service in sortedServices"
							:key="service.name"
							:disabled="!service.available"
						>
							<ion-label>
								<span>{{ service.name }}</span>
							</ion-label>

							<ion-reorder slot="end" />
						</ion-item>
					</ion-reorder-group>
				</ion-list>
			</template>
			<template v-else v-for="service in sortedServices" :key="service.name">
				<ion-list inset>
					<ion-item :disabled="!service.available">
						<ion-label>
							<span>{{ service.name }}</span>
						</ion-label>

						<ion-toggle
							slot="end"
							:checked="service.enabled.value"
							@ion-change="service.enabled.value = !service.enabled.value"
						/>
					</ion-item>
				</ion-list>
				<ion-note>{{ service.description }}</ion-note>
			</template>

			<ion-note color="medium" class="ion-padding">
				Order of Lyrics Services determines which ones will be fetched first.
			</ion-note>
		</ion-content>
	</AppPage>
</template>

<style scoped>
#lyrics-services-page-content {
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

			& ion-title {
				transform-origin: top center;
				margin: 0;
				padding-inline: 0;
			}
		}

		& > ion-note {
			text-wrap: balance;
		}
	}

	& ion-note {
		display: inline-block;
	}

	& > ion-list {
		margin-bottom: 0.25rem;

		& ion-item {
			--background: var(--ion-background-color-step-150, #ebebeb);
		}

		& ion-reorder {
			margin-left: 8px;
		}

		& ~ ion-note {
			font-size: 0.8rem;
			padding-inline: var(--ion-padding, 16px);
		}
	}
}
</style>
