<template>
	<song-menu :song>
		<ion-item :button="true" :detail="false" @click="playNow">
			<ion-icon aria-hidden="true" :icon="playIcon" slot="end" />
			Play now
		</ion-item>

		<ion-item :button="true" :detail="false" @click="playNext">
			<ion-icon aria-hidden="true" :icon="hourglassIcon" slot="end" />
			Play next
		</ion-item>

		<ion-item :button="true" :detail="false" @click="addToQueue">
			<ion-icon aria-hidden="true" :icon="addIcon" slot="end" />
			Add to queue
		</ion-item>

		<ion-item :button="true" :detail="false" @click="modifyMetadata">
			<ion-icon aria-hidden="true" :icon="documentIcon" slot="end" />
			Modify metadata
		</ion-item>
	</song-menu>
</template>

<script setup lang="ts">
import {
	IonItem,
	IonIcon,
	IonModal,
	actionSheetController,
	modalController,
	popoverController,
} from "@ionic/vue";
import {
	playOutline as playIcon,
	hourglassOutline as hourglassIcon,
	addOutline as addIcon,
	documentOutline as documentIcon,
} from "ionicons/icons";
import SongMenu from "@/components/SongMenu.vue";

import { AnySong, useMusicPlayer } from "@/stores/music-player";
import SongMetadataModal from "@/components/SongMetadataModal.vue";
import { useSongMetadata } from "@/stores/metadata";

const { song } = defineProps<{ song: AnySong }>();

const musicPlayer = useMusicPlayer();

async function playNow() {
	musicPlayer.addToQueue(song, musicPlayer.queueIndex);
	await popoverController.dismiss();
}

async function playNext() {
	musicPlayer.addToQueue(song, musicPlayer.queueIndex + 1);
	await popoverController.dismiss();
}

async function addToQueue() {
	musicPlayer.addToQueue(song);
	await popoverController.dismiss();
}

const songMetadata = useSongMetadata();
const metadata = songMetadata.getReactiveMetadata(song);
async function modifyMetadata() {
	const modal = await modalController.create({
		component: SongMetadataModal,
		componentProps: { metadata, song },

		async canDismiss({ modified }) {
			if (!modified) {
				return true;
			}

			const actionSheet = await actionSheetController.create({
				header: "You have made some changes",
				subHeader: "What do you want to happen to them?",
				buttons: [
					{ text: "Save", role: "selected", data: { action: "save" } },
					{ text: "Discard", role: "destructive", data: { action: "discard" } },
				],
			});

			await actionSheet.present();
			const info = await actionSheet.onWillDismiss();

			switch (info?.data?.action) {
				case "save":
					await songMetadata.setMetadata(song, metadata);
					return true;
				case "discard":
					return true;
				default:
					return false;
			}
		},
	});

	await modal.present();
	await modal.onDidDismiss();
	await popoverController.dismiss();
}
</script>
