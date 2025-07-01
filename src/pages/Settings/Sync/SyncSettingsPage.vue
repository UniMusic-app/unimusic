<script setup lang="ts">
import {
	IonContent,
	IonHeader,
	IonIcon,
	IonItem,
	IonList,
	IonNote,
	IonSpinner,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";
import {
	downloadOutline as importIcon,
	earthOutline as namespacesIcon,
	shareOutline as shareIcon,
	syncOutline as syncIcon,
} from "ionicons/icons";

import AppPage from "@/components/AppPage.vue";

import { useSync } from "@/stores/sync";

const sync = useSync();
</script>

<template>
	<AppPage
		title="Sync"
		back-button="Settings"
		:show-content-header="false"
		:force-inline-view="false"
	>
		<ion-content id="sync-page-content" class="ion-padding">
			<header>
				<ion-icon :icon="syncIcon" color="primary" />
				<ion-header collapse="condense">
					<ion-toolbar>
						<ion-title class="ion-text-nowrap" size="large">Sync</ion-title>
					</ion-toolbar>
				</ion-header>
				<ion-note>
					You can choose a folder which you want to share.
					<wbr />
					Files will be synced from and to that folder.
				</ion-note>
			</header>

			<ion-list inset>
				<ion-item lines="full" button router-link="/settings/sync/import">
					<ion-icon slot="start" :icon="importIcon" color="primary" />
					Import Songs
				</ion-item>

				<ion-item lines="full" button router-link="/settings/sync/share">
					<ion-icon slot="start" :icon="shareIcon" color="primary" />
					Share Songs
				</ion-item>
			</ion-list>

			<ion-list inset>
				<ion-item v-if="sync.status === 'syncing'" lines="full" :detail="false">
					<ion-spinner slot="start" color="primary" />
					Syncing...
				</ion-item>
				<ion-item v-else lines="full" button @click="sync.syncFiles()" :detail="false">
					<ion-icon slot="start" :icon="syncIcon" color="primary" />
					Sync Now
				</ion-item>

				<ion-item lines="full" button router-link="/settings/sync/namespaces" :detail="false">
					<ion-icon slot="start" :icon="namespacesIcon" color="primary" />
					Manage namespaces
				</ion-item>
			</ion-list>
		</ion-content>
	</AppPage>
</template>

<style scoped>
#sync-page-content {
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
		& > ion-item {
			--background: var(--ion-background-color-step-150, #ebebeb);
		}
	}
}
</style>
