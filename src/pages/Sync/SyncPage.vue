<script setup lang="ts">
import { IonButton, IonInput } from "@ionic/vue";
import { onMounted, ref } from "vue";

import AppPage from "@/components/AppPage.vue";

import UniMusicSync from "@/plugins/UniMusicSync";
import { SyncData, useSync } from "@/stores/sync";

const sync = useSync();

const author = ref("Unknown");
const importedTicket = ref("");
const tickets = ref<string[]>([]);
const data = ref<SyncData>();
onMounted(() => {
	setTimeout(async () => {
		author.value = (await UniMusicSync.getAuthor()).author;

		data.value = sync.syncData();

		tickets.value = await sync.shareSongs();
	}, 1500);
});
</script>

<template>
	<AppPage title="Sync">
		<h1>SYNC TEST</h1>

		<h2>Author: {{ author }}</h2>

		<p>Data:{{ JSON.stringify(data) }}</p>

		<h4>Namespaces</h4>
		<ul v-if="data">
			<li v-for="namespace in data.namespaces" :key="namespace">{{ namespace.slice(0, 20) }}...</li>
		</ul>

		<h4>Tickets</h4>
		<ul>
			<li v-for="ticket in tickets" :key="ticket">
				{{ ticket }}
			</li>
		</ul>

		<ion-input label="ticket" v-model="importedTicket" />
		<ion-button @click="sync.importSongs([importedTicket])">Import</ion-button>

		<ion-button @click="sync.syncDirectory('/MUSIC')">SYNC /MUSIC</ion-button>
	</AppPage>
</template>
