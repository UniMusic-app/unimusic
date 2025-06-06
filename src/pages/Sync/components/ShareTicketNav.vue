<script setup lang="ts">
import { Share } from "@capacitor/share";
import QR from "qr-code-styling";
import { onMounted, onUnmounted, ref } from "vue";

import {
	IonButton,
	IonButtons,
	IonContent,
	IonHeader,
	IonIcon,
	IonNote,
	IonTitle,
	IonToolbar,
	toastController,
} from "@ionic/vue";
import { clipboardOutline as clipboardIcon, ticketOutline as ticketIcon } from "ionicons/icons";

import AppPage from "@/components/AppPage.vue";

const { ticket } = defineProps<{
	ticket: string;
}>();

const ticketQr = ref();
const canShare = ref(false);

onMounted(async () => {
	const qr = new QR({
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
		data: ticket,
	});

	const blob = await qr.getRawData("svg");
	if (!blob) return;

	const url = URL.createObjectURL(blob as Blob);
	ticketQr.value = url;

	const { value } = await Share.canShare();
	if (value) {
		canShare.value = true;
	}
});

onUnmounted(() => {
	if (ticketQr.value) {
		URL.revokeObjectURL(ticketQr.value);
	}
});

async function copyTicket(): Promise<void> {
	await navigator.clipboard.writeText(ticket);

	const positionAnchor =
		document.querySelector<HTMLElement>("#mini-music-player") ??
		document.querySelector<HTMLElement>("ion-tab-bar") ??
		undefined;

	const toast = await toastController.create({
		header: `Copied ticket to clipboard`,
		icon: clipboardIcon,

		duration: 2000,
		translucent: true,
		swipeGesture: "vertical",
		positionAnchor,
	});
	await toast.present();
}

async function share(): Promise<void> {
	await Share.share({
		dialogTitle: "Share this ticket with device you want to sync with!",
		title: "UniMusicSync Ticket",
		text: `UniMusicSync ticket: ${ticket}. Keep in mind that this ticket can be short lived, don't hold it for too long!`,
	});
}
</script>

<template>
	<AppPage title="Share Ticket" back-button="Back" :show-content-header="false">
		<template #toolbar-end>
			<ion-buttons>
				<ion-button v-if="canShare" @click="share">Share</ion-button>
			</ion-buttons>
		</template>

		<ion-content id="share-ticket-content" class="ion-padding">
			<header>
				<ion-header collapse="condense">
					<ion-toolbar>
						<ion-title class="ion-text-nowrap" size="large">
							Share Ticket
							<ion-icon :icon="ticketIcon" color="primary" />
						</ion-title>
					</ion-toolbar>
				</ion-header>
				<ion-note>
					Share this ticket with device you want to sync with.
					<wbr />
					Keep in mind that this ticket can be short lived, don't hold it for too long!
				</ion-note>
			</header>

			<img
				v-if="ticketQr"
				:src="ticketQr"
				class="ticket-qr-code"
				alt="Library synchronization ticket in the form of QR code"
			/>

			<div class="ticket">
				<code aria-label="Library synchronization ticket">
					{{ ticket }}
				</code>
				<ion-button class="copy-ticket" size="large" @click="copyTicket" color="light">
					<ion-icon slot="icon-only" :icon="clipboardIcon" />
				</ion-button>
			</div>
		</ion-content>
	</AppPage>
</template>

<style scoped>
#share-ticket-content {
	& > header {
		text-align: center;
		margin-inline: auto;
		margin-bottom: 16px;

		& > ion-header {
			margin-inline: auto;
			width: max-content;
		}

		& ion-title {
			transform-origin: top center;
			margin: 0;

			& > ion-icon {
				font-size: 0.8em;
			}
		}

		& > ion-note {
			display: inline-block;
			text-wrap: balance;
		}
	}

	& > .ticket-qr-code {
		display: block;
		width: 100%;
		max-width: 384px;
		margin-inline: auto;
		margin-bottom: 16px;
	}

	& > .ticket {
		display: flex;
		justify-content: center;
		gap: 8px;
		width: 100%;
		max-width: 384px;
		margin-inline: auto;

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
