/* eslint-disable no-var */
import { createPinia } from "pinia";
import { createApp } from "vue";

import App from "@/pages/App.vue";
import router from "@/pages/router";

/** Ionic Webcomponents */
import { IonicVue } from "@ionic/vue";

/* Core CSS required for Ionic components to work properly */
import "@ionic/vue/css/core.css";

/* Basic CSS for apps built with Ionic */
import "@ionic/vue/css/normalize.css";
import "@ionic/vue/css/structure.css";
import "@ionic/vue/css/typography.css";

/* Optional CSS utils that can be commented out */
import "@ionic/vue/css/display.css";
import "@ionic/vue/css/flex-utils.css";
import "@ionic/vue/css/float-elements.css";
import "@ionic/vue/css/padding.css";
import "@ionic/vue/css/text-alignment.css";
import "@ionic/vue/css/text-transformation.css";

/**
 * Ionic Dark Mode
 * -----------------------------------------------------
 * For more info, please see:
 * https://ionicframework.com/docs/theming/dark-mode
 */

/* @import '@ionic/vue/css/palettes/dark.always.css'; */
/* @import '@ionic/vue/css/palettes/dark.class.css'; */
import "@ionic/vue/css/palettes/dark.system.css";

/* Theme variables */
import "./theme/variables.css";
import { getPlatform, isMobilePlatform } from "./utils/os";

/* Vue store */
const pinia = createPinia();

declare global {
	var __IS_ELECTRON__: boolean;

	var __SERVICE_LOCAL__: boolean;
	var __SERVICE_YOUTUBE__: boolean;
	var __SERVICE_MUSICKIT__: boolean;
}

async function main(): Promise<void> {
	if (__IS_ELECTRON__) {
		await import("./electron");
	} else if (isMobilePlatform()) {
		await import("./mobile");
	}

	const app = createApp(App)
		.use(IonicVue, {
			mode: "ios",
			swipeBackEnabled: getPlatform() === "ios",
		})
		.use(router)
		.use(pinia);

	await router.isReady().then(() => {
		app.mount("#app");
	});
}

void main();
