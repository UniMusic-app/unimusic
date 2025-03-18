<script lang="ts" setup>
import { IonItem, IonLabel, IonSkeletonText, IonThumbnail } from "@ionic/vue";

function randomIntBetween(min: number, max: number): number {
	return Math.floor(Math.random() * (max - min) + min);
}
</script>

<template>
	<ion-item class="skeleton-item">
		<ion-thumbnail slot="start">
			<ion-skeleton-text :animated="true" />
		</ion-thumbnail>

		<ion-label>
			<h1>
				<ion-skeleton-text :animated="true" :style="`width: ${randomIntBetween(40, 70)}%`" />
			</h1>
			<p>
				<ion-skeleton-text :animated="true" :style="`width: ${randomIntBetween(20, 30)}%`" />
			</p>
		</ion-label>
	</ion-item>
</template>

<style>
@keyframes show-up {
	from {
		opacity: 0%;
	}

	to {
		opacity: 100%;
	}
}

.skeleton-item {
	animation: show-up 250ms ease-in;

	& > ion-thumbnail {
		--border-radius: 12px;
	}
}
</style>
