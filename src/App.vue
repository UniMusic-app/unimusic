<template>
	<ion-app>
		<ion-tabs>
			<ion-router-outlet></ion-router-outlet>

			<ion-tab-bar slot="bottom">
				<ion-tab-button tab="home" href="/home">
					<ion-icon aria-hidden="true" :icon="home" />
					<ion-label>Home</ion-label>
				</ion-tab-button>

				<ion-tab-button tab="search" href="/search">
					<ion-icon aria-hidden="true" :icon="search" />
					<ion-label>Search</ion-label>
				</ion-tab-button>
			</ion-tab-bar>
		</ion-tabs>
	</ion-app>
</template>

<script setup lang="ts">
import {
	IonApp,
	IonRouterOutlet,
	IonTabs,
	IonTabBar,
	IonTabButton,
	IonIcon,
	IonLabel,
} from "@ionic/vue";
import { search, home } from "ionicons/icons";
</script>
