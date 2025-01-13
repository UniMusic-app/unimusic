<template>
	<div
		id="music-player-modal"
		class="ion-padding"
		v-if="currentSong"
		:style="{
			'--bg-color': `#${currentSong.data?.attributes?.artwork.bgColor ?? '000'}`,
		}"
	>
		<img
			class="artwork"
			:src="currentSong.artworkUrl"
			:alt="`Artwork for song '${currentSong.name}'`"
		/>

		<h1 class="title ion-text-nowrap">
			{{ currentSong.name }}
		</h1>
		<h2 class="artist ion-text-nowrap">
			{{ currentSong.artist }}
		</h2>

		<div class="time-controls">
			<ion-range
				aria-label="Time"
				:min="0"
				:max="1"
				:step="0.001"
				:value="progress"
				@ion-change="progress = $event.detail.value as number"
			/>

			<div class="labels">
				<ion-label>{{ secondsToMMSS(currentTime) }}</ion-label>
				<ion-label class="platform">
					<template v-if="currentSong.type === 'musickit'">Apple Music</template>
				</ion-label>
				<ion-label>{{ secondsToMMSS(timeRemaining) }}</ion-label>
			</div>
		</div>

		<ion-buttons>
			<ion-button size="large" :disabled="!hasPrevious" @click="musicPlayer.skipPrevious">
				<ion-icon :icon="skipPreviousIcon" slot="icon-only" />
			</ion-button>
			<ion-button :disabled="loading" size="large" @click="musicPlayer.togglePlay">
				<ion-spinner v-if="loading" />
				<ion-icon v-else :icon="playing ? pauseIcon : playIcon" slot="icon-only" />
			</ion-button>
			<ion-button size="large" :disabled="!hasNext" @click="musicPlayer.skipNext">
				<ion-icon :icon="skipNextIcon" slot="icon-only" />
			</ion-button>
		</ion-buttons>

		<div class="volume-controls">
			<ion-range
				aria-label="Volume"
				:min="0"
				:max="1"
				:step="0.001"
				:value="volume"
				@ion-change="volume = $event.detail.value as number"
			>
				<ion-icon slot="start" :icon="volumeLowIcon" />
				<ion-icon slot="end" :icon="volumeHighIcon" />
			</ion-range>
		</div>

		<!-- TODO: Queue -->
	</div>
</template>

<style scoped>
#music-player-modal {
	position: relative;
	user-select: none;

	background: linear-gradient(0deg, color-mix(in srgb, var(--bg-color), black), var(--bg-color));

	color: white;
	ion-icon,
	ion-spinner {
		color: white;
	}

	height: 100%;
	width: 100%;

	display: flex;
	flex-direction: column;

	justify-content: center;
	align-items: center;

	& > .artwork {
		pointer-events: none;
		border-radius: 16px;
		box-shadow: 0 0 60px #0004;
	}

	& > .time-controls,
	& > .volume-controls {
		display: flex;
		flex-direction: column;
		width: 100%;
		padding-inline: 16px;

		& > .labels {
			display: flex;
			align-items: center;
			justify-content: space-between;

			& > .platform {
				font-weight: bold;
			}
		}
	}

	& > .time-controls {
		margin-bottom: 16px;
	}

	& > .volume-controls {
		margin-top: 32px;
	}

	ion-range {
		--bar-background: #bcbcbc;
		--bar-background-active: #ffffff;
		--bar-height: 8px;
		--bar-border-radius: 8px;
		--knob-size: 0;
	}

	ion-button {
		height: 72px;
		width: 72px;
		font-size: 1.5rem;
	}

	& > .title {
		max-width: 90vw;
		font-size: 1.2rem;
		text-overflow: ellipsis;
		overflow: hidden;
		margin-bottom: 0;
	}

	& > .artist {
		margin-top: 0;
		font-weight: bold;
	}
}
</style>

<script setup lang="ts">
import { storeToRefs } from "pinia";
import { useMusicPlayer } from "@/stores/music-player";

import {
	play as playIcon,
	pause as pauseIcon,
	playSkipBack as skipPreviousIcon,
	playSkipForward as skipNextIcon,
	volumeLow as volumeLowIcon,
	volumeHigh as volumeHighIcon,
	time as timeIcon,
} from "ionicons/icons";
import { IonButton, IonButtons, IonIcon, IonSpinner, IonRange, IonLabel } from "@ionic/vue";
import { secondsToMMSS } from "@/utils/time";

const musicPlayer = useMusicPlayer();
const {
	playing,
	currentSong,
	volume,
	hasPrevious,
	hasNext,
	loading,
	currentTime,
	progress,
	timeRemaining,
} = storeToRefs(musicPlayer);
</script>
