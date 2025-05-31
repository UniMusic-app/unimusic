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
	IonTitle,
	IonToolbar,
} from "@ionic/vue";
import { clipboardOutline as clipboardIcon, shareOutline as shareIcon } from "ionicons/icons";
import QR from "qr-code-styling";
import { ref, useTemplateRef } from "vue";

import DirectoryPicker from "@/components/DirectoryPicker.vue";
import { useSync } from "@/stores/sync";
import { pathBreadcrumbs } from "@/utils/path";
import { usePresentingElement } from "@/utils/vue";

const sync = useSync();

const { trigger } = defineProps<{ trigger: string }>();

const modal = useTemplateRef("modal");
const presentingElement = usePresentingElement();

const directory = ref<string>();
const expanded = ref(false);
const ticket = ref();
const ticketQR = ref();

function changeDirectory(event: string): void {
	directory.value = event;
	expanded.value = false;
}

function resetModal(): void {
	directory.value = undefined;
	if (ticketQR.value) {
		URL.revokeObjectURL(ticketQR.value);
	}
	ticketQR.value = undefined;
	ticket.value = undefined;
	expanded.value = false;
}

function dismiss(): void {
	modal.value?.$el.dismiss();
}

async function generateTicket(): Promise<void> {
	if (!directory.value) {
		return;
	}

	URL.revokeObjectURL(ticketQR.value);

	const namespace = await sync.createNamespace(directory.value);
	const sharedTicket = await sync.shareNamespace(namespace);

	ticket.value = sharedTicket;

	const qrCode = new QR({
		width: 512,
		height: 512,
		type: "svg",
		backgroundOptions: {
			round: 0.1,
			color: "#141414",
		},
		cornersDotOptions: {
			type: "extra-rounded",
		},
		cornersSquareOptions: {
			type: "extra-rounded",
		},
		dotsOptions: {
			type: "classy-rounded",
			gradient: {
				type: "linear",
				colorStops: [
					{ color: "#006BDE", offset: 0 },
					{ color: "#ECA1FF", offset: 0.6 },
				],
				rotation: -Math.PI / 4,
			},
		},
		image: "/favicon.png",
		imageOptions: {
			hideBackgroundDots: true,
			margin: 8,
			crossOrigin: "anonymous",
		},
		shape: "square",
		data: sharedTicket,
	});

	const blob = await qrCode.getRawData("svg");
	if (!blob) {
		return;
	}
	const url = URL.createObjectURL(blob as Blob);
	ticketQR.value = url;

	await sync.syncFiles();
}

async function copyTicket(): Promise<void> {
	await navigator.clipboard.writeText(ticket.value);
}
</script>

<template>
	<ion-modal ref="modal" :trigger :presenting-element="presentingElement" @will-dismiss="resetModal">
		<ion-header>
			<ion-toolbar>
				<ion-buttons slot="start">
					<ion-button color="danger" @click="dismiss()">Cancel</ion-button>
				</ion-buttons>

				<ion-title>Share Songs</ion-title>
			</ion-toolbar>
		</ion-header>

		<ion-content id="share-songs-content" :fullscreen="true" class="ion-padding">
			<template v-if="!directory">
				<h1>Select folder to share:</h1>
				<p>
					<ion-note>
						Files from that folder will be shared and synchronized bilaterally with your devices
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
							<ion-breadcrumb v-for="breadcrumb in pathBreadcrumbs(directory)" :key="breadcrumb">
								<span>{{ breadcrumb }}</span>
							</ion-breadcrumb>
						</ion-breadcrumbs>
					</ion-item>
				</ion-list>
			</template>

			<div class="actions">
				<DirectoryPicker @change="changeDirectory($event)" />

				<ion-button :disabled="!directory" @click="generateTicket">
					<ion-icon slot="start" :icon="shareIcon" />
					Create ticket
				</ion-button>
			</div>

			<img
				v-if="ticketQR"
				class="ticket-qr-code"
				:src="ticketQR"
				alt="Library synchronization ticket in the form of QR code"
			/>

			<div class="ticket" v-if="ticket">
				<code aria-label="Library synchronization ticket">
					{{ ticket }}
				</code>
				<ion-button class="copy-ticket" size="large" @click="copyTicket">
					<ion-icon slot="icon-only" :icon="clipboardIcon" />
				</ion-button>
			</div>
		</ion-content>
	</ion-modal>
</template>

<style>
#share-songs-content {
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
	}

	& > ion-list {
		background: transparent;
		& > ion-item {
			--background: transparent;
		}
		margin-bottom: 16px;
	}

	& > .ticket {
		display: flex;
		justify-content: center;
		width: 100%;
		gap: 8px;

		& > code {
			position: relative;
			width: 80%;

			@supports (line-clamp: 4) {
				line-clamp: 4;
			}

			@supports not (line-clamp: 4) {
				display: -webkit-box;
				-webkit-box-orient: vertical;
				-webkit-line-clamp: 4;
				overflow: hidden;
			}
		}

		& > .copy-ticket {
			flex-grow: 1;
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
