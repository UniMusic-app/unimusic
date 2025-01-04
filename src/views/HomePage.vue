<template>
	<ion-page>
		<ion-header :translucent="true">
			<ion-toolbar>
				<ion-title>Music Player</ion-title>
			</ion-toolbar>
		</ion-header>

		<ion-content :fullscreen="true">
			<ion-header collapse="condense">
				<ion-toolbar>
					<ion-title size="large">Music Player</ion-title>
				</ion-toolbar>
			</ion-header>

			<div v-if="authorized" id="container">
				<h1>You are authorized</h1>
				<ion-button @click="unauthorizeAppleMusic">Unauthorize Apple Music</ion-button>
			</div>
			<div v-else id="container">
				<h1>You are unauthorized</h1>
				<ion-button @click="authorizeAppleMusic">Authorize Apple Music</ion-button>
			</div>

			<p id="error" v-if="error">
				{{ error }}
			</p>
		</ion-content>
	</ion-page>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { IonContent, IonHeader, IonPage, IonTitle, IonToolbar, IonButton } from "@ionic/vue";
import MusicKitAuthorization from "@/plugins/MusicKitAuthorization";

const authorized = ref(false);
const error = ref("");

async function authorizeAppleMusic(): Promise<void> {
	try {
		const music = await MusicKitAuthorization.authorize();
		authorized.value = music.isAuthorized;
	} catch (err) {
		if (err instanceof Error) {
			error.value = err.message;
		} else {
			error.value = String(err);
		}
	}
}

async function unauthorizeAppleMusic(): Promise<void> {
	const music = MusicKit.getInstance()!;
	await music.unauthorize();
	authorized.value = music.isAuthorized;
}
</script>

<style scoped>
#container {
	text-align: center;

	position: absolute;
	left: 0;
	right: 0;
	top: 50%;
	transform: translateY(-50%);
}

#container strong {
	font-size: 20px;
	line-height: 26px;
}

#container p {
	font-size: 16px;
	line-height: 22px;

	color: #8c8c8c;

	margin: 0;
}

#container a {
	text-decoration: none;
}
</style>
