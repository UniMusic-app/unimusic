<script setup lang="ts">
import { IonContent, IonIcon, IonItem, IonList } from "@ionic/vue";

import {
	hammerOutline as developmentIcon,
	// @ts-expect-error it actually exists
	readerOutline as lyricsServicesIcon,
	idCardOutline as metadataServicesIcon,
	musicalNotesOutline as musicServicesIcon,
	syncOutline as syncIcon,
} from "ionicons/icons";

import AppPage from "@/components/AppPage.vue";

import DevelopmentMainNav from "../Development/MainNav.vue";
import LyricsServicesMainNav from "../LyricsServices/MainNav.vue";
import MetadataServicesMainNav from "../MetadataServices/MainNav.vue";
import MusicServicesMainNav from "../MusicServices/MainNav.vue";
import SyncMainNav from "../Sync/MainNav.vue";

const props = defineProps<{ nav: HTMLIonNavElement }>();
const nav = props.nav;
</script>

<template>
	<AppPage title="Settings" :force-inline-view="false">
		<ion-content id="settings-page-content" class="ion-padding">
			<ion-list lines="full" inset>
				<ion-item button @click="nav.push(SyncMainNav, { nav })">
					<ion-icon slot="start" :icon="syncIcon" color="primary" />
					Sync
				</ion-item>
			</ion-list>

			<ion-list lines="full" inset>
				<ion-item button @click="nav.push(MusicServicesMainNav, { nav })">
					<ion-icon slot="start" :icon="musicServicesIcon" color="primary" />
					Music Services
				</ion-item>

				<ion-item button @click="nav.push(LyricsServicesMainNav, { nav })">
					<ion-icon slot="start" :icon="lyricsServicesIcon" color="primary" />
					Lyrics Services
				</ion-item>

				<ion-item button @click="nav.push(MetadataServicesMainNav, { nav })">
					<ion-icon slot="start" :icon="metadataServicesIcon" color="primary" />
					Metadata Services
				</ion-item>
			</ion-list>

			<ion-list lines="full" inset>
				<ion-item button @click="nav.push(DevelopmentMainNav, { nav })">
					<ion-icon slot="start" :icon="developmentIcon" color="primary" />
					Development
				</ion-item>
			</ion-list>
		</ion-content>
	</AppPage>
</template>

<style scoped>
#settings-page-content {
	& > header {
		text-align: center;
		margin-inline: auto;
		margin-bottom: 16px;

		& > ion-icon {
			font-size: 4rem;
			width: 100%;
		}

		& > ion-header {
			margin-inline: auto;
			width: max-content;

			& ion-title {
				transform-origin: top center;
				margin: 0;
				padding-inline: 0;
			}
		}

		& > ion-note {
			display: inline-block;
			text-wrap: balance;
		}
	}

	& > ion-list {
		& > ion-item {
			--background: var(--ion-background-color-step-150, #ebebeb);
		}
	}
}
</style>
