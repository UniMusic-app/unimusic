<script setup lang="ts">
import { IonButton, IonIcon, toastController } from "@ionic/vue";
import { folderOutline as directoryIcon, warningOutline as warningIcon } from "ionicons/icons";

import DirectoryPicker from "@/plugins/DirectoryPicker";

const emit = defineEmits<{ change: [path: string] }>();

const { iconColor } = defineProps<{ iconColor?: string }>();

async function pickDirectories(): Promise<void> {
	try {
		const { path } = await DirectoryPicker.pickDirectory();
		emit("change", path);
	} catch (error) {
		const positionAnchor =
			document.querySelector<HTMLElement>("#mini-music-player") ??
			document.querySelector<HTMLElement>("ion-tab-bar") ??
			undefined;
		const toast = await toastController.create({
			header: "Failed picking directories",
			message: error instanceof Error ? error.message : String(error),

			color: "warning",
			icon: warningIcon,
			duration: 3000,
			translucent: true,
			swipeGesture: "vertical",
			positionAnchor,
		});
		await toast.present();
	}
}
</script>

<template>
	<ion-button class="directory-picker" @click="pickDirectories">
		<ion-icon :color="iconColor" slot="start" :icon="directoryIcon" />
		Choose folder
	</ion-button>
</template>
