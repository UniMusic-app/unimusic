<script setup lang="ts">
import {
	IonContent,
	IonHeader,
	IonIcon,
	IonItem,
	IonLabel,
	IonList,
	IonNote,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";

import { hammerOutline as developmentIcon } from "ionicons/icons";

import AppPage from "@/components/AppPage.vue";
import { clearCache } from "@/services/Music/objects";
import { useLocalImages } from "@/stores/local-images";

const localImages = useLocalImages();

function clearObjectCache(): void {
	clearCache();
}

async function clearImageCache(): Promise<void> {
	await localImages.clearImages();
}

function clearStorage(): void {
	localStorage.clear();
}
</script>

<template>
	<AppPage title="Sync" :show-content-header="false" :force-inline-view="false">
		<ion-content id="development-page-content" class="ion-padding">
			<header>
				<ion-icon :icon="developmentIcon" color="primary" />
				<ion-header collapse="condense">
					<ion-toolbar>
						<ion-title class="ion-text-nowrap" size="large">Development</ion-title>
					</ion-toolbar>
				</ion-header>
				<ion-note>These options have been created for debugging and development purposes.</ion-note>
			</header>

			<ion-list inset>
				<ion-item @click="clearObjectCache" button :detail="false">
					<ion-label>
						<span>Clear object cache</span>
						<p>Resets cached songs, artists, etc.</p>
					</ion-label>
				</ion-item>

				<ion-item @click="clearImageCache" button :detail="false">
					<ion-label>
						<span>Clear image cache</span>
						<p>Deletes local images from cache</p>
					</ion-label>
				</ion-item>

				<ion-item @click="clearStorage" button :detail="false">
					<ion-label>
						<span>Clear storage</span>
						<p>Clears localStorage</p>
					</ion-label>
				</ion-item>
			</ion-list>
		</ion-content>
	</AppPage>
</template>

<style scoped>
#development-page-content {
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
