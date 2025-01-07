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

			<div v-if="musicKit.authorized" id="container">
				<h1>You are authorized</h1>
				<ion-button @click="unauthorizeAppleMusic">Unauthorize Apple Music</ion-button>
				<ion-input v-model="songName" label="Song name" />
				<ion-button @click="playSong">Play the song!</ion-button>
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
import {
	IonContent,
	IonHeader,
	IonPage,
	IonTitle,
	IonToolbar,
	IonButton,
	IonInput,
} from "@ionic/vue";
import { useMusicKit } from "@/stores/musickit";

const musicKit = useMusicKit();
const error = ref("");
const songName = ref("Rick Astley - Never Gonna Give You Up");

async function playSong() {
	await musicKit.withMusic(async (music) => {
		const queryParameters = {
			term: songName.value,
			types: ["songs"],
		};

		const result = await music.api.music<MusicKit.SearchResponse>(
			"/v1/catalog/{{storefrontId}}/search",
			queryParameters,
		);

		const songs = result.data.results.songs?.data;
		if (songs) {
			const firstSong = songs[0];
			const attributes = firstSong.attributes;

			console.log("Start playing", attributes?.name, "by", attributes?.artistName);
			await music.setQueue({ song: firstSong.id });
			console.log(music.queue.length);
			music.play();
			console.log(music.nowPlayingItem);
		}
	});
}

async function authorizeAppleMusic(): Promise<void> {
	try {
		await musicKit.authService.authorize();
	} catch (e) {
		error.value = String(e);
	}
}

async function unauthorizeAppleMusic(): Promise<void> {
	try {
		await musicKit.authService.unauthorize();
	} catch (e) {
		error.value = String(e);
	}
}
</script>

<style scoped>
#container {
	display: flex;
	flex-direction: column;
	text-align: center;

	position: absolute;
	top: 50%;
	left: 50%;
	transform: translateX(-50%);
	width: 100%;
	max-width: min(800px, 100vw);
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
