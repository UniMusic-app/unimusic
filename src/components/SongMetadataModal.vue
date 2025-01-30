<template>
	<!-- TODO: Artwork, duration and resetting -->
	<ion-header>
		<ion-toolbar>
			<ion-title>Metadata</ion-title>
			<ion-buttons slot="end">
				<ion-button :strong="true" @click="close">Close</ion-button>
			</ion-buttons>
		</ion-toolbar>
	</ion-header>

	<ion-content>
		<ion-list>
			<ion-item>
				<ion-input
					label="Title"
					label-placement="floating"
					:placeholder="song.title ?? 'Never Gonna Give You Up'"
					:value="metadata.title ?? song.title"
					@ion-input="onInput('title', $event)"
				/>
			</ion-item>

			<ion-item>
				<ion-input
					label="Artist"
					label-placement="floating"
					:placeholder="song.artist ?? 'Rick Astley'"
					:value="metadata.artist ?? song.artist"
					@ion-input="onInput('artist', $event)"
				/>
			</ion-item>

			<ion-item>
				<ion-input
					label="Album"
					label-placement="floating"
					:placeholder="song.album ?? 'Whenever You Need Somebody'"
					:value="metadata.album ?? song.album"
					@ion-input="onInput('album', $event)"
				/>
			</ion-item>

			<ion-item>
				<ion-input
					label="Genre"
					label-placement="floating"
					:placeholder="song.genre ?? 'Dance-pop'"
					:value="metadata.genre ?? song.genre"
					@ion-input="onInput('genre', $event)"
				/>
			</ion-item>
		</ion-list>
	</ion-content>
</template>

<script setup lang="ts">
import { MetadataOverride } from "@/stores/metadata";
import { AnySong } from "@/stores/music-player";
import {
	IonHeader,
	IonToolbar,
	IonButton,
	IonTitle,
	IonButtons,
	IonContent,
	IonItem,
	IonInput,
	IonList,
	modalController,
	InputCustomEvent,
} from "@ionic/vue";
import { ref } from "vue";

const { song, metadata } = defineProps<{ song: AnySong; metadata: MetadataOverride }>();

function onInput(key: keyof MetadataOverride, event: InputCustomEvent) {
	modify(key, `${event.target.value}`);
}

let modified = ref(false);
function modify<K extends keyof MetadataOverride>(key: K, value: MetadataOverride[K]) {
	metadata[key] = value;
	modified.value = true;
}

async function close() {
	await modalController.dismiss({ modified: modified.value }, "close");
	modified.value = false;
}
</script>
