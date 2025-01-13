<template>
	<Transition name="roll">
		<ion-header v-if="show" :translucent="true">
			<slot name="leading" />

			<ion-toolbar id="app-toolbar">
				<slot name="toolbar" />

				<ion-buttons slot="end">
					<ion-button @click="userModalOpen = true" id="open-user-modal">
						<ion-icon size="large" slot="icon-only" :icon="personCircle" />
					</ion-button>
				</ion-buttons>
			</ion-toolbar>

			<slot name="trailing" />
		</ion-header>
	</Transition>

	<ion-modal ref="userModal" :is-open="userModalOpen" @didDismiss="userModalOpen = false">
		<UserModal :modal="userModal" />
	</ion-modal>
</template>

<script setup lang="ts">
import { IonHeader, IonToolbar, IonButtons, IonButton, IonIcon, IonModal } from "@ionic/vue";
import { personCircle } from "ionicons/icons";

import UserModal from "@/components/UserModal.vue";
import { ref } from "vue";

const { show = true } = defineProps<{
	show?: boolean;
}>();

const userModal = ref();
const userModalOpen = ref(false);
</script>

<style scoped>
.roll-enter-active,
.roll-leave-active {
	height: 54px;
	@supports (interpolate-size: allow-keywords) {
		height: auto;
	}

	transition:
		opacity,
		height,
		0.4s ease-out;
}

.roll-enter-from,
.roll-leave-to {
	opacity: 0;
	height: 0;
}
</style>
