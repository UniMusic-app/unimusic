<script lang="ts" setup>
import { ref } from "vue";

import {
	IonBreadcrumb,
	IonBreadcrumbs,
	IonButton,
	IonButtons,
	IonContent,
	IonHeader,
	IonIcon,
	IonItem,
	IonList,
	IonNote,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";
import { shareOutline as shareIcon } from "ionicons/icons";

import AppPage from "@/components/AppPage.vue";
import DirectoryPicker from "@/components/DirectoryPicker.vue";

import { useSync } from "@/stores/sync";
import { pathBreadcrumbs } from "@/utils/path";

const sync = useSync();

const directory = ref<string>();
const expanded = ref(false);
const ticket = ref("test");

async function generateTicket(): Promise<void> {
	if (!directory.value) {
		return;
	}

	const namespace = await sync.getOrCreateNamespace(directory.value);
	const sharedTicket = await sync.shareNamespace(namespace);

	ticket.value = sharedTicket;

	await sync.syncFiles();
}

async function changeDirectory(event: string): Promise<void> {
	directory.value = event;
	expanded.value = false;

	await generateTicket();
}
</script>

<template>
	<AppPage title="Share Songs" :show-content-header="false">
		<template #toolbar-end>
			<ion-buttons>
				<ion-button v-if="ticket" :router-link="`/settings/sync/share/ticket?ticket=${ticket}`">
					Get ticket
				</ion-button>
				<ion-button v-else disabled>Get ticket</ion-button>
			</ion-buttons>
		</template>

		<ion-content id="share-songs-content" class="ion-padding">
			<header>
				<ion-icon :icon="shareIcon" color="primary" />
				<ion-header collapse="condense">
					<ion-toolbar>
						<ion-title class="ion-text-nowrap" size="large">Share Songs</ion-title>
					</ion-toolbar>
				</ion-header>
				<ion-note>
					Choose a folder which you want to share.
					<wbr />
					Files will be synced from and to that folder.
				</ion-note>
			</header>

			<template v-if="directory">
				<h1>Selected folder:</h1>
				<ion-list>
					<ion-item @click="expanded = !expanded" lines="none">
						<ion-breadcrumbs
							class="path-breadcrumbs"
							:class="{ expanded }"
							:max-items="expanded ? undefined : 2"
							:items-before-collapse="1"
							:items-after-collapse="1"
						>
							<ion-breadcrumb v-for="breadcrumb in pathBreadcrumbs(directory)" :key="breadcrumb">
								<span>{{ breadcrumb }}</span>
							</ion-breadcrumb>
						</ion-breadcrumbs>
					</ion-item>
				</ion-list>
			</template>

			<DirectoryPicker @change="changeDirectory($event)" expand="block" />
		</ion-content>
	</AppPage>
</template>

<style>
#share-songs-content {
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

	& > h1 {
		text-align: center;
		font-weight: 550;
	}

	& > ion-list {
		background: transparent;
		& > ion-item {
			--background: transparent;
		}
		margin-bottom: 16px;
	}

	& > .share-button {
		margin-top: auto;
	}

	.path-breadcrumbs {
		flex-wrap: nowrap;
		&.expanded {
			flex-wrap: wrap;
		}

		width: 100%;
		cursor: pointer;

		& > ion-breadcrumb::part(native) {
			padding: 0;
		}

		& > ion-breadcrumb > span {
			white-space: nowrap;
			overflow: hidden;
			text-overflow: ellipsis;
			white-space: nowrap;
		}
	}
}
</style>
