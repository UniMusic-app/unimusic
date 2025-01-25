<template>
	<div
		id="music-player-modal"
		class="ion-padding"
		v-if="currentSong"
		:style="{ '--bg-color': bgColor }"
	>
		<div class="song" :class="{ compact: showQueue }">
			<!-- FIXME: Make artwork optional -->
			<img
				class="artwork"
				:src="currentSong.artworkUrl"
				:alt="`Artwork for song '${currentSong.title}'`"
			/>

			<div class="song-info">
				<h1 class="title ion-text-nowrap">
					{{ currentSong.title }}
				</h1>
				<h2 class="artist ion-text-nowrap">
					{{ currentSong.artist }}
				</h2>
			</div>
		</div>

		<ion-content class="queue" v-if="showQueue">
			<!-- TODO: Add reorder -->
			<h1>Queue</h1>
			<ion-list lines="none">
				<ion-item
					button
					:detail="false"
					v-for="(song, i) in queuedSongs"
					:key="i"
					:class="{ current: i === queueIndex }"
					@click.self="queueIndex = i"
				>
					<ion-thumbnail slot="start">
						<img :src="song.artworkUrl" :alt="`Artwork for song '${song.title}'`" />
					</ion-thumbnail>

					<ion-label class="ion-text-nowrap">
						<h2>{{ song.title }}</h2>
						<ion-note>
							{{ song.artist }}
						</ion-note>
					</ion-label>

					<ion-button @click="musicPlayer.remove(i)" fill="clear" slot="end">
						<ion-icon slot="icon-only" :icon="removeIcon" />
					</ion-button>
				</ion-item>
			</ion-list>
		</ion-content>

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
				<ion-label>{{ secondsToMMSS(time) }}</ion-label>
				<ion-label class="platform">
					{{ songTypeDisplayName(currentSong) }}
				</ion-label>
				<ion-label>{{ secondsToMMSS(timeRemaining) }}</ion-label>
			</div>
		</div>

		<ion-buttons class="media-controls">
			<ion-button
				aria-label="Skip to previous song"
				size="large"
				:disabled="!hasPrevious"
				@click="musicPlayer.skipPrevious"
			>
				<ion-icon aria-hidden="true" :icon="skipPreviousIcon" slot="icon-only" />
			</ion-button>
			<ion-button
				aria-label="Play or pause the song"
				:disabled="loading"
				size="large"
				@click="musicPlayer.togglePlay"
			>
				<ion-spinner v-if="loading" />
				<ion-icon v-else aria-hidden="true" :icon="playing ? pauseIcon : playIcon" slot="icon-only" />
			</ion-button>
			<ion-button
				aria-label="Skip to next song"
				size="large"
				:disabled="!hasNext"
				@click="musicPlayer.skipNext"
			>
				<ion-icon aria-hidden="true" :icon="skipNextIcon" slot="icon-only" />
			</ion-button>
		</ion-buttons>

		<!-- NOTE: volume control does not work on iOS due to Apple putting arbitrary restrictions around setting app volume -->
		<div class="volume-controls" v-if="getPlatform() !== 'ios'">
			<ion-range
				aria-label="Volume"
				:min="0"
				:max="1"
				:step="0.001"
				:value="volume"
				@ion-change="volume = $event.detail.value as number"
			>
				<ion-icon aria-hidden="true" slot="start" :icon="volumeLowIcon" />
				<ion-icon aria-hidden="true" slot="end" :icon="volumeHighIcon" />
			</ion-range>
		</div>

		<div class="actions">
			<ion-button fill="clear" aria-label="Lyrics">
				<ion-icon slot="icon-only" :icon="musicalNotesIcon" />
			</ion-button>

			<ion-button
				:fill="showQueue ? 'solid' : 'clear'"
				aria-label="Queue"
				@click="showQueue = !showQueue"
			>
				<ion-icon slot="icon-only" :icon="listIcon" />
			</ion-button>
		</div>
	</div>
</template>

<style scoped>
#music-player-modal {
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

	& > .song {
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		width: 100%;
		height: 60%;

		&.compact {
			flex-direction: row;
			height: 160px;
			gap: 8px;

			& > .artwork {
				width: 128px;
			}

			& > .song-info {
				width: calc(100% - 128px);
			}

			margin: 0;
		}

		& > .artwork {
			width: 256px;
			pointer-events: none;
			border-radius: 16px;
			box-shadow: 0 0 60px #0004;
		}

		& > .song-info {
			display: flex;
			flex-direction: column;
			justify-content: center;
			align-items: center;

			& > .title {
				font-size: 1.2rem;
			}

			& > .artist {
				margin-top: 0;
				font-weight: bold;
			}

			& > .title,
			& > .artist {
				max-width: min(100%, 80vw);
				text-overflow: ellipsis;
				overflow: hidden;
				margin-bottom: 0;
			}
		}
	}

	& > .queue {
		max-height: calc(60% - 160px);
		margin: 0;
		--background: transparent;

		& > h1 {
			color: white;
			font-weight: bolder;
		}

		& > ion-list {
			background: transparent;
			& > ion-item {
				&.current {
					background-color: #fff2;
					border-radius: 12px;
				}

				&::part(native) {
					--background: transparent;
				}

				& h2 {
					pointer-events: none;
					color: white;
					font-weight: bold;
				}

				& ion-label {
					pointer-events: none;
				}

				& ion-note {
					pointer-events: none;
					font-weight: 500;
					color: #dedede;
				}

				& > ion-thumbnail {
					--border-radius: 8px;
					pointer-events: none;
				}

				& > ion-button {
					height: 48px;
					width: 48px;
					font-size: 1rem;
				}
			}
		}
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

	& > .media-controls {
		& > ion-button {
			height: 72px;
			width: 72px;
			font-size: 1.5rem;
		}
	}

	& > .actions {
		display: flex;
		width: 100%;
		justify-content: space-evenly;
		align-items: center;

		& > ion-button {
			width: 64px;
			height: 64px;
			font-size: 1.5rem;
		}
	}
}
</style>

<script setup lang="ts">
import { ref, computed } from "vue";
import { storeToRefs } from "pinia";

import {
	play as playIcon,
	pause as pauseIcon,
	playSkipBack as skipPreviousIcon,
	playSkipForward as skipNextIcon,
	volumeLow as volumeLowIcon,
	volumeHigh as volumeHighIcon,
	list as listIcon,
	musicalNotes as musicalNotesIcon,
	trash as removeIcon,
} from "ionicons/icons";
import {
	IonList,
	IonButton,
	IonButtons,
	IonIcon,
	IonNote,
	IonContent,
	IonSpinner,
	IonRange,
	IonLabel,
	IonItem,
	IonThumbnail,
} from "@ionic/vue";

import { useMusicPlayer } from "@/stores/music-player";

import { getPlatform } from "@/utils/os";
import { secondsToMMSS } from "@/utils/time";
import { songTypeDisplayName } from "@/utils/songs";

const musicPlayer = useMusicPlayer();
const {
	queueIndex,
	queuedSongs,
	playing,
	currentSong,
	volume,
	hasPrevious,
	hasNext,
	loading,
	time,
	progress,
	timeRemaining,
} = storeToRefs(musicPlayer);

const showQueue = ref(false);

const bgColor = computed(() => {
	const song = currentSong.value;

	switch (song?.type) {
		case "musickit": {
			const color = song.data.bgColor;
			return color ? `#${color}` : "#000";
		}
		case "local": {
			// Get an "average" color from the artwork image
			if (song?.artworkUrl) {
				const image = new Image(1, 1);
				image.src = song.artworkUrl;

				const context = document.createElement("canvas").getContext("2d");
				if (!context) {
					return "#000";
				}

				context.drawImage(image, 0, 0);
				const [r, g, b] = context.getImageData(0, 0, 1, 1).data;
				return `rgb(${r}, ${g}, ${b})`;
			}
			return "#000";
		}
		default:
			return "#000";
	}
});
</script>
