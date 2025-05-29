<script lang="ts" setup>
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
	IonModal,
	IonNote,
	IonTitle,
	IonToolbar,
	toastController,
} from "@ionic/vue";
import {
	addOutline as addIcon,
	downloadOutline as importIcon,
	warningOutline as warningIcon,
} from "ionicons/icons";
import { ref, useTemplateRef } from "vue";

import DirectoryPicker from "@/components/DirectoryPicker.vue";
import { NamespaceId } from "@/plugins/UniMusicSync";
import { useSync } from "@/stores/sync";
import { pathBreadcrumbs } from "@/utils/path";
import { usePresentingElement } from "@/utils/vue";
import {
	CapacitorBarcodeScanner,
	CapacitorBarcodeScannerTypeHint,
} from "@capacitor/barcode-scanner";

const sync = useSync();

const { trigger } = defineProps<{ trigger: string }>();

const modal = useTemplateRef("modal");
const presentingElement = usePresentingElement();

const directory = ref<string>();
const expanded = ref(false);
const loading = ref(false);

function changeDirectory(event: string): void {
	directory.value = event;
	expanded.value = false;
}

function resetModal(): void {
	directory.value = undefined;
	expanded.value = false;
}

function dismiss(): void {
	modal.value?.$el.dismiss();
}

async function importTicket(): Promise<void> {
	if (!directory.value) {
		return;
	}

	loading.value = true;

	let namespace: NamespaceId;
	try {
		const { ScanResult: maybeTicket } = await CapacitorBarcodeScanner.scanBarcode({
			hint: CapacitorBarcodeScannerTypeHint.QR_CODE,
			scanText: "Scan UniMusicSync QR code",
		});

		namespace = await sync.importNamespace(maybeTicket, directory.value);
	} catch (error) {
		const toast = await toastController.create({
			header: `Import failed!`,
			message: error instanceof Error ? error.message : String(error),

			color: "warning",
			icon: warningIcon,
			duration: 3000,
			translucent: true,
			swipeGesture: "vertical",
			positionAnchor: "mini-music-player",
		});
		await toast.present();
		loading.value = false;
		return;
	}

	const toast = await toastController.create({
		header: `Import successful!`,
		message: `Imported namespace ${namespace.slice(0, 6)}...`,
		icon: addIcon,

		duration: 2000,
		translucent: true,
		swipeGesture: "vertical",
		positionAnchor: "mini-music-player",
	});
	await toast.present();

	loading.value = false;
}
</script>

<template>
	<ion-modal ref="modal" :trigger :presenting-element="presentingElement" @will-dismiss="resetModal">
		<ion-header>
			<ion-toolbar>
				<ion-buttons slot="start">
					<ion-button color="danger" @click="dismiss()">Cancel</ion-button>
				</ion-buttons>

				<ion-title>Import Songs</ion-title>
			</ion-toolbar>
		</ion-header>

		<ion-content id="import-songs-content" :fullscreen="true" class="ion-padding">
			<template v-if="!directory">
				<h1>Select destination folder:</h1>
				<p>
					<ion-note>
						Files will be shared and synchronized bilaterally with your devices from and to that folder
					</ion-note>
				</p>
			</template>
			<template v-else>
				<h1>Selected folder:</h1>
				<ion-list>
					<ion-item @click="expanded = !expanded">
						<ion-breadcrumbs
							class="path-breadcrumbs"
							:class="{ expanded: expanded }"
							:max-items="expanded ? undefined : 2"
							:items-before-collapse="1"
							:items-after-collapse="1"
						>
							<ion-breadcrumb v-for="breadcrumb in pathBreadcrumbs(directory)">
								<span>{{ breadcrumb }}</span>
							</ion-breadcrumb>
						</ion-breadcrumbs>
					</ion-item>
				</ion-list>
			</template>

			<div class="actions">
				<DirectoryPicker @change="changeDirectory($event)" />

				<ion-button :disabled="!directory" @click="importTicket">
					<template v-if="loading">
						<ion-spinner slot="start" />
						Loading...
					</template>
					<template v-else>
						<ion-icon slot="start" :icon="importIcon" />
						Import ticket
					</template>
				</ion-button>
			</div>
		</ion-content>
	</ion-modal>
</template>

<style>
#import-songs-content {
	& > h1 {
		margin-bottom: 0;
	}
	& > p {
		margin: 0;
		margin-bottom: 8px;
	}

	& > .actions {
		display: flex;
		gap: 8px;
		align-items: center;
		justify-content: space-evenly;

		& > ion-button > ion-spinner {
			margin-right: 0.5rem;
			width: 1em;
			height: 1em;
		}
	}

	& > ion-list {
		background: transparent;
		& > ion-item {
			--background: transparent;
		}
		margin-bottom: 16px;
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
