<script setup lang="ts">
import { IonButton } from "@ionic/vue";

import AppPage from "@/components/AppPage.vue";

import { useSync } from "@/stores/sync";
import ImportSongsModal from "./components/ImportSongsModal.vue";
import ShareSongsModal from "./components/ShareSongsModal.vue";

const sync = useSync();
</script>

<template>
	<AppPage title="Sync">
		<ion-button id="share-songs">Share songs</ion-button>
		<ShareSongsModal trigger="share-songs" />
		<ion-button id="import-songs">Import songs</ion-button>
		<ImportSongsModal trigger="import-songs" />
		<ion-button @click="sync.syncFiles()">Sync</ion-button>
	</AppPage>
</template>
