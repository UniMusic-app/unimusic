<script lang="ts" setup>
import {
	IonButton,
	IonContent,
	IonHeader,
	IonIcon,
	IonInput,
	IonItem,
	IonNote,
	IonSpinner,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";
import {
	alertCircle as failureIcon,
	downloadOutline as importIcon,
	qrCodeOutline as qrImportIcon,
	checkmarkOutline as successIcon,
	ticketOutline as ticketIcon,
} from "ionicons/icons";
import { onMounted, ref } from "vue";

import AppPage from "@/components/AppPage.vue";
import { useSync } from "@/stores/sync";
import {
	CapacitorBarcodeScanner,
	CapacitorBarcodeScannerTypeHint,
} from "@capacitor/barcode-scanner";

const sync = useSync();

const { directory, method } = defineProps<{
	directory: string;
	method: "qr" | "manual";
}>();

const status = ref<"idle" | "scanning" | "importing" | "success" | "failure">("idle");
const statusMessage = ref<string>();
const ticket = ref();

if (method === "qr") {
	onMounted(async () => {
		try {
			status.value = "scanning";
			await scanTicketQRCode();
			await importTicket();
		} catch (error) {
			console.error(error);
			status.value = "failure";
			if (error) {
				statusMessage.value = parseErrorMessage(error);
			} else {
				statusMessage.value = "Error cause is unknown";
			}
		}
	});
}

function parseErrorMessage(error: unknown): string {
	if (error instanceof Error) {
		return error.message;
	}

	if (typeof error === "object" && "errorMessage" in error!) {
		return String(error.errorMessage);
	}

	return String(error);
}

async function scanTicketQRCode(): Promise<void> {
	const { ScanResult: maybeTicket } = await CapacitorBarcodeScanner.scanBarcode({
		hint: CapacitorBarcodeScannerTypeHint.QR_CODE,
		scanText: "Scan UniMusicSync QR code",
	});
	ticket.value = maybeTicket;
}

async function importTicket(): Promise<void> {
	if (!directory || !ticket.value) {
		return;
	}

	statusMessage.value = "";
	status.value = "importing";

	try {
		const namespace = await sync.importNamespace(ticket.value, directory);
		const namespaceShort = `${namespace.slice(0, 6)}...`;

		status.value = "success";
		statusMessage.value = `Successfully imported namespace ${namespaceShort}`;
	} catch (error) {
		console.error(error);
		status.value = "failure";
		if (error) {
			statusMessage.value = parseErrorMessage(error);
		} else {
			statusMessage.value = "Error cause is unknown";
		}
	}
}
</script>

<template>
	<AppPage title="Import Songs" back-button="Back" :show-content-header="false">
		<template #toolbar-end></template>

		<ion-content id="import-ticket-content" class="ion-padding">
			<header>
				<ion-spinner v-if="status === 'importing'" />
				<ion-icon v-else-if="status === 'success'" :icon="successIcon" color="success" />
				<ion-icon v-else-if="status === 'failure'" :icon="failureIcon" color="danger" />
				<ion-icon v-else-if="status === 'scanning'" :icon="qrImportIcon" color="medium" />
				<ion-icon v-else :icon="ticketIcon" color="primary" />

				<ion-header collapse="condense">
					<ion-toolbar>
						<ion-title class="ion-text-nowrap" size="large">Import Ticket</ion-title>
					</ion-toolbar>
				</ion-header>
				<ion-note>
					<template v-if="statusMessage">
						{{ statusMessage }}
					</template>
					<template v-else-if="method === 'qr'">Scan a QR Code of the ticket.</template>
					<template v-else>
						Enter the ticket below.
						<wbr />
						Keep in mind that the ticket should start with
					</template>
				</ion-note>
			</header>

			<template v-if="method !== 'qr'">
				<ion-item class="ticket-input">
					<ion-input :disabled="!directory || status === 'importing'" label="Ticket" v-model="ticket" />
				</ion-item>

				<div class="actions">
					<ion-button :disabled="!directory || !ticket || status === 'importing'" @click="importTicket">
						<template v-if="status === 'importing'">
							<ion-spinner slot="start" />
							Importing...
						</template>
						<template v-else>
							<ion-icon slot="start" :icon="importIcon" />
							Import ticket
						</template>
					</ion-button>
				</div>
			</template>
		</ion-content>
	</AppPage>
</template>

<style>
#import-ticket-content {
	& > header {
		text-align: center;
		margin-inline: auto;
		margin-bottom: 16px;

		& > ion-icon {
			font-size: 4rem;
			width: 100%;
		}

		& > ion-spinner {
			height: 4rem;
			width: 3rem;
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
			max-width: 100%;
			display: inline-block;
			text-wrap: balance;
		}
	}

	& > .ticket-input {
		margin-bottom: 0.5rem;
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
