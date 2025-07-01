<script setup lang="ts">
import {
	IonButton,
	IonContent,
	IonHeader,
	IonIcon,
	IonItem,
	IonLabel,
	IonList,
	IonNote,
	IonTitle,
	IonToggle,
	IonToolbar,
} from "@ionic/vue";
import { musicalNotes as musicServicesIcon } from "ionicons/icons";

import AppPage from "@/components/AppPage.vue";
import { useMusicServices } from "@/stores/music-services";
import { songTypeToDisplayName } from "@/utils/songs";
import { computed } from "vue";

const services = useMusicServices();

const sortedServices = computed(() => {
	const registeredServices = services.registeredServices;
	return Object.values(registeredServices).sort((a, b) => {
		if (a.available && !b.available) return -1;
		return songTypeToDisplayName(a.type).localeCompare(songTypeToDisplayName(b.type));
	});
});
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
				<ion-icon :icon="musicServicesIcon" color="primary" />
				<ion-header collapse="condense">
					<ion-toolbar>
						<ion-title class="ion-text-nowrap" size="large">Music</ion-title>
					</ion-toolbar>
				</ion-header>
				<ion-note>Music Services enable you to discover and listen to music content.</ion-note>
			</header>

			<template v-for="service in sortedServices" :key="service.type">
				<ion-list inset>
					<ion-item :disabled="!service.available">
						<ion-label>
							<span>{{ songTypeToDisplayName(service.type) }}</span>
						</ion-label>

						<template v-if="service.enabled.value && service.authorization">
							<ion-button
								slot="end"
								v-if="service.authorization.authorized.value"
								@click="service.authorization.unauthorize()"
							>
								Unauthorize
							</ion-button>
							<ion-button v-else slot="end" @click="service.authorization.authorize()">
								Authorize
							</ion-button>
						</template>

						<ion-toggle
							slot="end"
							:checked="service.enabled.value"
							@ion-change="service.enabled.value = !service.enabled.value"
						/>
					</ion-item>
				</ion-list>
				<ion-note>{{ service.description }}</ion-note>
			</template>
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

		& > ion-item {
			--background: var(--ion-background-color-step-150, #ebebeb);

			& ion-button {
				margin-right: 12px;
			}
		}

		& + ion-note {
			font-size: 0.8rem;
			padding-inline: var(--ion-padding, 16px);
		}
	}
}
</style>
