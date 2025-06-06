<script setup lang="ts">
import { IonNav, IonPage, onIonViewWillLeave } from "@ionic/vue";
import { useTemplateRef } from "vue";

import SyncMainNav from "./components/MainNav.vue";

const nav = useTemplateRef<{ $el: HTMLIonNavElement }>("nav");

onIonViewWillLeave(async () => {
	await nav.value?.$el.popToRoot({
		duration: 100,
	});
});
</script>

<template>
	<ion-page>
		<ion-nav ref="nav" :root="SyncMainNav" :root-params="{ nav: nav?.$el }" />
	</ion-page>
</template>
