<script lang="ts" setup>
import {
	IonBreadcrumb,
	IonBreadcrumbs,
	IonContent,
	IonHeader,
	IonIcon,
	IonItem,
	IonList,
	IonNote,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";
import {
	downloadOutline as importIcon,
	textOutline as manualImportIcon,
	qrCodeOutline as qrImportIcon,
} from "ionicons/icons";
import { ref } from "vue";

import AppPage from "@/components/AppPage.vue";
import DirectoryPicker from "@/components/DirectoryPicker.vue";
import { pathBreadcrumbs } from "@/utils/path";
import ImportTicketNav from "./ImportTicketNav.vue";

const props = defineProps<{ nav: HTMLIonNavElement }>();
const nav = props.nav;

const directory = ref<string>();
const expanded = ref(false);

function changeDirectory(event: string): void {
	directory.value = event;
	expanded.value = false;
}
</script>

<template>
	<AppPage title="Import Songs" back-button="Back" :show-content-header="false">
		<ion-content :fullscreen="true" id="import-songs-content" class="ion-padding">
			<header>
				<ion-icon :icon="importIcon" color="primary" />
				<ion-header collapse="condense">
					<ion-toolbar>
						<ion-title class="ion-text-nowrap" size="large">Import Songs</ion-title>
					</ion-toolbar>
				</ion-header>
				<ion-note>
					Choose a folder which you want to share.
					<wbr />
					Files will be synced into and to that folder.
				</ion-note>
			</header>

			<template v-if="directory">
				<h1>Selected folder:</h1>
				<ion-list>
					<ion-item @click="expanded = !expanded" lines="none">
						<ion-breadcrumbs
							class="path-breadcrumbs"
							:class="{ expanded: expanded }"
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

			<ion-list class="import-options" inset>
				<ion-item
					:disabled="!directory"
					button
					@click="nav.push(ImportTicketNav, { directory, method: 'qr' })"
				>
					<ion-icon slot="start" color="primary" :icon="qrImportIcon" />
					Use QR Code
				</ion-item>

				<ion-item
					:disabled="!directory"
					button
					@click="nav.push(ImportTicketNav, { directory, method: 'manual' })"
				>
					<ion-icon slot="start" color="primary" :icon="manualImportIcon" />
					Enter ticket manually
				</ion-item>
			</ion-list>
		</ion-content>
	</AppPage>
</template>

<style>
#import-songs-content {
	& > header {
		text-align: center;
		margin-inline: auto;
		margin-bottom: 16px;

		& > ion-icon {
			font-size: 4rem;
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
			width: 100%;
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

	& > .import-options {
		margin-inline: 0;
		& > ion-item {
			--background: var(--ion-background-color-step-150, #ebebeb);
		}
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
