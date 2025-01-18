<template>
	<ion-page>
		<app-header>
			<template #toolbar>
				<ion-title>Library</ion-title>
			</template>
		</app-header>

		<ion-content :fullscreen="true" class="ion-padding">
			<ion-list>
				<local-song-item v-for="song in songs" :key="song.id" :song />
			</ion-list>

			{{ songs.length }}
		</ion-content>

		<app-footer />
	</ion-page>
</template>

<script setup lang="ts">
import { IonPage, IonTitle, IonContent, IonList } from "@ionic/vue";
import AppHeader from "@/components/AppHeader.vue";
import AppFooter from "@/components/AppFooter.vue";
import { onMounted, ref } from "vue";
import LocalMusicPlugin, { type LocalMusicSong } from "@/plugins/LocalMusicPlugin";
import LocalSongItem from "@/components/SongItem/LocalSongItem.vue";

const songs = ref<LocalMusicSong[]>([]);

onMounted(async () => {
	songs.value = await LocalMusicPlugin.getSongs();
});
</script>
