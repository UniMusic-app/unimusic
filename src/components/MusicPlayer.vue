<script setup lang="ts">
import { computed, ref, shallowRef, useTemplateRef, watch } from "vue";

import {
	IonButton,
	IonContent,
	IonIcon,
	IonItem,
	IonItemDivider,
	IonLabel,
	IonList,
	IonListHeader,
	IonModal,
	IonNote,
	IonRange,
	IonReorderGroup,
	IonSpinner,
	ItemReorderCustomEvent,
} from "@ionic/vue";
import {
	albumsOutline as albumIcon,
	personOutline as artistIcon,
	volumeHigh as highVolumeIcon,
	volumeLow as lowVolumeIcon,
	musicalNotes as lyricsIcon,
	pause as pauseIcon,
	play as playIcon,
	listOutline as playLastIcon,
	playOutline as playNextIcon,
	list as queueIcon,
	trashOutline as removeIcon,
	playSkipForward as skipNextIcon,
	playSkipBack as skipPreviousIcon,
	musicalNotesOutline as songIcon,
} from "ionicons/icons";

import ContextMenu from "@/components/ContextMenu.vue";
import GenericSongItem from "@/components/GenericSongItem.vue";
import LocalImg from "@/components/LocalImg.vue";
import WrappingMarquee from "@/components/WrappingMarquee.vue";

import { useLocalImages } from "@/stores/local-images";
import { useMusicPlayer } from "@/stores/music-player";
import { useNavigation } from "@/stores/navigation";

import { filledDisplayableArtist, Song } from "@/services/Music/objects";

import { Lyrics } from "@/services/Lyrics/LyricsService";
import { getPlatform, isMobilePlatform } from "@/utils/os";
import { formatArtists, songTypeToDisplayName } from "@/utils/songs";
import { secondsToMMSS } from "@/utils/time";
import { Maybe } from "@/utils/types";
import { watchAsync } from "@/utils/vue";
import { Haptics } from "@capacitor/haptics";
import { storeToRefs } from "pinia";

const musicPlayer = useMusicPlayer();
const localImages = useLocalImages();
const navigation = useNavigation();

const state = musicPlayer.state;
const { currentSong, time } = storeToRefs(state);

const modal = useTemplateRef("music-player");

const supportsVolume = getPlatform() !== "ios";
const currentView = ref<"artwork" | "queue" | "lyrics">("artwork");

const lyricsElement = useTemplateRef("lyrics-element");
const lyrics = shallowRef<Lyrics>();
const loadingLyrics = ref(false);
let previousLyricsSong: Maybe<Song>;
const lyricsIndex = ref(-1);
watchAsync(
	() => [currentSong.value, currentView.value] as const,
	async ([song, view]) => {
		if (!song || (song === previousLyricsSong && lyrics.value) || view !== "lyrics") return;

		try {
			lyrics.value = undefined;
			lyricsIndex.value = -1;

			previousLyricsSong = song;

			loadingLyrics.value = true;
			lyrics.value = await musicPlayer.services.getLyrics(song);
			loadingLyrics.value = false;
		} catch {
			lyrics.value = undefined;
		}
	},
);

const lastScroll = ref<number>(0);
watch(time, (time) => {
	const syncedLyrics = lyrics.value?.syncedLyrics;
	if (!syncedLyrics) return;

	const index = syncedLyrics.findLastIndex((line) => time >= line.timestamp);
	lyricsIndex.value = index;

	requestAnimationFrame(() => {
		// Don't autoscroll if user manually scrolled within last 3 seconds
		if (Date.now() - lastScroll.value < 3000) return;

		const element = lyricsElement.value!.$el as HTMLElement;
		const lineElement = element.querySelector<HTMLElement>(".lyrics-line.current");
		if (!lineElement) return;

		element.scrollTo({
			top: lineElement.offsetTop - 32,
			behavior: "smooth",
		});
	});
});

const artworkStyle = computed(() => {
	const artwork = state.currentSong?.artwork;
	const style = artwork?.style ?? localImages.getStyle(artwork?.id);

	return {
		"--bg": style?.bgGradient ?? "#000",
		"--bg-color": style?.bgColor ?? "#000",
		"--fg-color": style?.fgColor ?? "#fff",
	};
});
const artworkElement = useTemplateRef("artwork");
const artworkBounding = ref<DOMRect>();
function updateArtworkBounding(): void {
	const artworkEl = artworkElement.value?.$el as HTMLImageElement | undefined;
	if (!artworkEl) return;
	artworkBounding.value = artworkEl.getBoundingClientRect();
}

const formattedArtists = computed(() =>
	formatArtists(state.currentSong?.artists?.map(filledDisplayableArtist)),
);
const currentTime = computed(() => secondsToMMSS(state.time));
const timeRemaining = computed(() => secondsToMMSS(musicPlayer.timeRemaining));
const currentService = computed(
	() => state.currentSong && songTypeToDisplayName(state.currentSong.type),
);

const seekPreview = ref(false);
const seekPreviewValue = ref(0);
const seekPreviewTime = computed(() => secondsToMMSS(seekPreviewValue.value * state.duration));
if (isMobilePlatform()) {
	watch([seekPreview, seekPreviewValue], async ([seekPreview, value]) => {
		if (!seekPreview || !(value === 0 || value === 1)) {
			return;
		}
		await Haptics.impact();
	});
}

const seekPreviewRemainingTime = computed(() =>
	secondsToMMSS(state.duration * (1 - seekPreviewValue.value)),
);

function dismiss(): void {
	modal.value?.$el?.dismiss();
}

function reorderQueue(event: ItemReorderCustomEvent): void {
	const { from, to } = event.detail;
	state.moveQueueItem(from, to);
	event.detail.complete();
}

function toggleView(view: "queue" | "lyrics"): void {
	if (currentView.value === view) {
		currentView.value = "artwork";
	} else {
		currentView.value = view;
	}
}
</script>

<template>
	<ion-modal
		ref="music-player"
		id="music-player"
		:show-backdrop="false"
		:keep-contents-mounted="true"
		:initial-breakpoint="1"
		:breakpoints="[0, 1]"
		:style="artworkStyle"
		@did-present="updateArtworkBounding"
	>
		<ion-content
			:scroll-y="false"
			:class="`${currentView}-view`"
			:style="{ '--bottom-height': supportsVolume ? '260px' : '220px' }"
		>
			<div class="music-player-wrapper">
				<div class="view-content">
					<LocalImg
						size="large"
						ref="artwork"
						:style="{
							'--top': `${artworkBounding?.top}px`,
							'--left': `${artworkBounding?.left}px`,
						}"
						class="artwork"
						:class="{ playing: state.playing, small: currentView !== 'artwork' }"
						:src="currentSong?.artwork"
					/>

					<ion-list
						ref="lyrics-element"
						class="lyrics ion-content-scroll-host"
						v-show="currentView === 'lyrics'"
						@scroll="lastScroll = Date.now()"
					>
						<template v-if="lyrics?.syncedLyrics">
							<ion-item
								v-for="({ line, timestamp }, i) in lyrics?.syncedLyrics"
								:key="timestamp"
								class="lyrics-line live"
								:class="{ current: i === lyricsIndex }"
								@click="musicPlayer.seekToTime(timestamp)"
								lines="none"
							>
								{{ line }}
							</ion-item>

							<ion-item class="attribution" lines="none">
								<span>
									Live lyrics provided by
									<a v-if="lyrics.provider.url" :href="lyrics.provider.url">{{ lyrics.provider.title }}</a>
									<template v-else>{{ lyrics.provider.title }}</template>
								</span>
							</ion-item>
						</template>
						<template v-else-if="lyrics?.lyrics">
							<ion-item
								v-for="(line, i) in lyrics?.lyrics"
								:key="i"
								class="lyrics-line"
								:class="{ current: i === lyricsIndex }"
								lines="none"
							>
								{{ line }}
							</ion-item>

							<ion-item class="attribution" lines="none">
								<span>
									Lyrics provided by
									<a v-if="lyrics.provider.url" :href="lyrics.provider.url">{{ lyrics.provider.title }}</a>
									<template v-else>{{ lyrics.provider.title }}</template>
								</span>
							</ion-item>
						</template>
						<template v-else-if="loadingLyrics">
							<ion-item class="info" lines="none">
								<span>
									<ion-spinner slot="start" />
									Loading lyrics...
								</span>
							</ion-item>
						</template>
						<template v-else>
							<ion-item class="info" lines="none">
								<span>No lyrics have been found for this song</span>
							</ion-item>
						</template>
					</ion-list>

					<ion-list class="queue ion-content-scroll-host" v-show="currentView === 'queue'">
						<ion-list-header>Queue</ion-list-header>
						<ion-reorder-group :disabled="false" @ion-item-reorder="reorderQueue">
							<GenericSongItem
								v-for="({ song, id }, i) in state.queue"
								reorder
								:song
								:key="id"
								:class="{ 'current-song': i === state.queueIndex }"
								:title="song.title"
								:artists="song.artists"
								:artwork="song.artwork"
								:type="song.type"
								@item-click="musicPlayer.setQueueIndex(i)"
								@context-menu-click="navigation.goToSong(song)"
							>
								<template #options>
									<ion-item
										aria-label="Play next"
										lines="full"
										button
										:detail="false"
										@click="state.moveQueueItem(i, state.queueIndex + 1)"
									>
										Play next
										<ion-icon aria-hidden="true" :icon="playNextIcon" slot="end" />
									</ion-item>
									<ion-item
										aria-label="Play last"
										lines="full"
										button
										:detail="false"
										@click="state.moveQueueItem(i, state.queue.length - 1)"
									>
										Play last
										<ion-icon aria-hidden="true" :icon="playLastIcon" slot="end" />
									</ion-item>

									<ion-item-divider />

									<ion-item
										@click="state.removeFromQueue(i)"
										class="remove-song-item"
										aria-label="Remove"
										lines="full"
										button
										:detail="false"
									>
										Remove
										<ion-icon aria-hidden="true" :icon="removeIcon" slot="end" />
									</ion-item>
								</template>
							</GenericSongItem>
						</ion-reorder-group>
					</ion-list>
				</div>

				<div ref="song-controls" class="song-controls">
					<div class="song-info" :class="{ small: currentView !== 'artwork' }">
						<ContextMenu event="click" :move="false" :backdrop="false" :haptics="false">
							<div class="song-details">
								<h1>
									<WrappingMarquee :text="currentSong?.title ?? 'Unknown title'" />
								</h1>
								<h2>
									<WrappingMarquee :text="formattedArtists" />
								</h2>
							</div>

							<template v-if="currentSong" #options>
								<ion-item
									aria-label="Go to Song"
									lines="full"
									button
									:detail="false"
									@click="(navigation.goToSong(currentSong), dismiss())"
								>
									<ion-label>
										Go to Song
										<ion-note>{{ currentSong?.title }}</ion-note>
									</ion-label>
									<ion-icon aria-hidden="true" :icon="songIcon" slot="end" />
								</ion-item>

								<ion-item
									aria-label="Go to Album"
									lines="full"
									button
									:detail="false"
									v-if="currentSong?.album"
									@click="(navigation.goToSongsAlbum(currentSong), dismiss())"
								>
									<ion-label>
										Go to Album
										<ion-note>{{ currentSong?.album }}</ion-note>
									</ion-label>
									<ion-icon aria-hidden="true" :icon="albumIcon" slot="end" />
								</ion-item>

								<ion-item
									aria-label="Go to artist"
									lines="full"
									button
									:detail="false"
									v-if="currentSong?.artists?.length"
									@click="(navigation.goToSongsArtist(currentSong), dismiss())"
								>
									<ion-label>
										Go to Artist
										<ion-note>{{ formattedArtists }}</ion-note>
									</ion-label>
									<ion-icon aria-hidden="true" :icon="artistIcon" slot="end" />
								</ion-item>
							</template>
						</ContextMenu>
					</div>

					<div class="time-control">
						<ion-range
							aria-label="Time"
							:snaps="false"
							:min="0"
							:max="1"
							:step="0.01"
							:value="seekPreview ? seekPreviewValue : musicPlayer.progress"
							@pointerdown="seekPreview = true"
							@pointerup="seekPreview = false"
							@ion-input="seekPreviewValue = <number>$event.detail.value"
							@ion-change="musicPlayer.progress = <number>$event.detail.value"
						/>

						<div class="time-control-labels">
							<p>{{ seekPreview ? seekPreviewTime : currentTime }}</p>
							<p>{{ currentService }}</p>
							<p>-{{ seekPreview ? seekPreviewRemainingTime : timeRemaining }}</p>
						</div>
					</div>

					<div class="player-controls">
						<ion-button
							aria-label="Skip to previous song"
							size="large"
							fill="clear"
							@click="musicPlayer.skipPrevious"
							:disabled="!musicPlayer.hasPrevious || musicPlayer.state.loading.queueChange"
						>
							<ion-icon aria-hidden="true" :icon="skipPreviousIcon" slot="icon-only" />
						</ion-button>

						<ion-button
							:aria-label="state.playing ? 'Pause' : 'Play'"
							size="large"
							fill="clear"
							@click="musicPlayer.togglePlay"
							:data-loading="musicPlayer.state.loading.playPause"
							:disabled="musicPlayer.state.loading.playPause"
						>
							<ion-icon aria-hidden="true" v-if="state.playing" :icon="pauseIcon" slot="icon-only" />
							<ion-icon aria-hidden="true" v-else :icon="playIcon" slot="icon-only" />
						</ion-button>

						<ion-button
							aria-label="Skip to next song"
							size="large"
							fill="clear"
							@click="musicPlayer.skipNext"
							:disabled="!musicPlayer.hasNext || musicPlayer.state.loading.queueChange"
						>
							<ion-icon aria-hidden="true" :icon="skipNextIcon" slot="icon-only" />
						</ion-button>
					</div>

					<div class="volume-control" v-if="supportsVolume">
						<ion-range
							aria-label="Volume"
							v-model="state.volume"
							:snaps="false"
							:min="0"
							:max="1"
							:step="0.01"
						>
							<ion-icon slot="start" :icon="lowVolumeIcon" size="small" />
							<ion-icon slot="end" :icon="highVolumeIcon" size="small" />
						</ion-range>
					</div>

					<div class="player-actions">
						<ion-button
							:aria-label="currentView === 'queue' ? 'Hide lyrics' : 'Open lyrics'"
							fill="clear"
							size="default"
							:class="{ toggled: currentView === 'lyrics' }"
							:disabled="!musicPlayer.services.canGetLyrics"
							@pointerdown="toggleView('lyrics')"
						>
							<ion-icon aria-hidden="true" :icon="lyricsIcon" slot="icon-only" />
						</ion-button>

						<ion-button
							:aria-label="currentView === 'queue' ? 'Hide song queue' : 'Open song queue'"
							class="queue-toggle"
							fill="clear"
							size="default"
							:class="{ toggled: currentView === 'queue' }"
							@pointerdown="toggleView('queue')"
						>
							<ion-icon :icon="queueIcon" slot="icon-only" />
						</ion-button>
					</div>
				</div>
			</div>
		</ion-content>
	</ion-modal>
</template>

<style scoped>
@keyframes slide-view {
	from {
		padding-top: 75vh;
		opacity: 0%;
	}

	to {
		padding-top: 0px;
		opacity: 100%;
	}
}

@keyframes song-info-fade {
	0%,
	33% {
		opacity: 0%;
		transform: translateY(-50%);
	}

	100% {
		opacity: 100%;
	}
}

@keyframes song-info-fade-small {
	0%,
	20% {
		opacity: 0%;
		transform: translateY(50%);
	}

	100% {
		opacity: 100%;
		transform: translateY(0);
	}
}

#music-player {
	--modal-handle-top: calc(var(--ion-safe-area-top) + 6px);
	@media screen and (min-width: 640px) {
		--modal-handle-top: calc(var(--ion-safe-area-top) + 24px);
	}

	&::part(handle) {
		background-color: white;
		opacity: 80%;
		box-shadow: 0 0 12px #0006;
		top: var(--modal-handle-top);
	}

	--width: 100%;
	--height: 100%;

	& ion-content {
		--background: var(--bg);
		&.lyrics-view {
			--background: var(--bg);
		}

		--color: white;
		--artwork-width: min(85vw, 50vh);

		& ion-button[size="large"] ion-icon {
			font-size: 2.5rem;
		}

		& ion-button[size="default"] ion-icon {
			font-size: 1.75rem;
		}

		& > .music-player-wrapper {
			display: flex;
			flex-direction: column;
			align-items: center;
			justify-content: center;

			width: 100%;
			height: 100%;

			& > .view-content {
				display: flex;
				flex-direction: column;
				align-items: center;
				justify-content: center;

				width: 100%;
				height: calc(100% - 260px);

				& > .artwork {
					--img-width: 100%;
					--img-height: auto;

					transition:
						transform,
						top,
						left,
						width,
						height,
						375ms cubic-bezier(0.32, 0.885, 0.55, 1);

					transform: scale(80%);
					&.playing {
						transform: scale(100%);
					}

					width: var(--artwork-width);

					--img-border-radius: 24px;

					&::after {
						content: "";
						position: absolute;
						top: 0;
						left: 0;
						width: 100%;
						height: 100%;
						border-radius: var(--img-border-radius);

						box-shadow:
							0 0 24px rgb(from var(--bg-color) r g b / 40%),
							0 0 48px #0004,
							inset 0 0 36px rgb(from var(--bg-color) r g b / 40%);
					}

					&.small {
						position: absolute;
						top: calc(var(--ion-safe-area-top) + 16px);
						left: calc(var(--ion-safe-area-left) + 16px);
						width: 3.5rem;
						--img-border-radius: 6px;
						transform: none;

						:deep(& img) {
							margin-block: auto;
							box-shadow: 0 0 6px #0003;
						}
					}
				}

				& > .queue,
				& > .lyrics {
					margin-top: calc(var(--ion-safe-area-top) + 80px);
					margin-inline: auto;
					width: 100%;
					height: 100%;

					overflow: auto;
					mask-image: linear-gradient(to bottom, transparent, black 5% 95%, transparent);

					animation: slide-view 375ms cubic-bezier(0.32, 0.885, 0.55, 1);

					transform-origin: bottom center;

					background: transparent;
					--background: transparent;
					padding-bottom: 16px;
				}

				& > .lyrics {
					overflow-x: hidden;

					& > ion-item {
						--background: transparent;
						--color: white;

						cursor: pointer;

						font-size: 1.5rem;
						font-weight: bold;
						padding-block: 8px;
						padding-right: 0.5rem;

						transition: transform, filter, opacity, 250ms;
						transform-origin: center left;

						&.current {
							transform: scale(103%);
						}

						&.live:not(.current):not(.attribution):not(:hover) {
							opacity: 50%;
						}

						&.attribution {
							font-size: 1rem;
							font-weight: 550;

							& a {
								text-decoration: underline;
								color: white;
							}
						}

						&.info {
							& > span {
								display: flex;
								align-items: center;
								justify-content: center;

								width: 100%;
								gap: 8px;
							}
						}
					}
				}

				& > .queue {
					& > ion-list-header {
						--background: transparent;
						--color: white;
						text-shadow: 0 2px 4px #0002;
						padding-bottom: 12px;
					}

					:deep(& .context-menu-item .song-item),
					:deep(& .context-menu:not(.opened) .song-item) {
						--background: transparent;
						--border-color: transparent;
						--color: white;

						&.current-song {
							--background: color-mix(in srgb, #fff2 70%, var(--bg-color));
						}

						& ion-note {
							color: white;
							opacity: 60%;
						}
					}

					:deep(& .remove-song-item) {
						--color: var(--ion-color-danger);
						&:hover {
							--color: var(--ion-color-danger-tint);
						}
						&:active {
							--color: var(--ion-color-danger-shade);
						}
					}
				}
			}

			& > .song-controls {
				display: flex;
				flex-direction: column;
				width: 80%;
				justify-content: end;

				margin-top: auto;
				margin-bottom: calc(var(--ion-safe-area-bottom) + 16px);
				margin-inline: auto;

				& > *:not(.song-info) {
					filter: drop-shadow(0 0 4px rgb(from var(--bg-color) r g b / 20%)) drop-shadow(0 0 12px #0002);
				}

				& > .song-info {
					display: block;

					transition: top 375ms cubic-bezier(0.32, 0.885, 0.55, 1);

					width: 80%;

					top: var(--top);
					left: var(--left);

					animation: song-info-fade 375ms cubic-bezier(0.32, 0.885, 0.55, 1);

					&.small {
						position: absolute;
						top: calc(var(--ion-safe-area-top) + 21px);
						left: calc(var(--ion-safe-area-left) + 84px);
						width: 70%;

						animation: song-info-fade-small 375ms cubic-bezier(0.32, 0.885, 0.55, 1);

						& .song-details {
							& > h1 {
								font-size: 1.25rem;
							}

							& > h2 {
								font-size: 1rem;
							}
						}
					}

					& .song-details {
						overflow: hidden;
						white-space: nowrap;
						color: white;
						max-width: 80vw;

						& > h1,
						& > h2 {
							transition: opacity 250ms ease;
							cursor: pointer;
							& .wrapping {
								mask-image: linear-gradient(to right, transparent, black 10% 90%, transparent);
							}
						}

						& > h1 {
							--marquee-duration: 20s;
							--marquee-gap: 12px;

							font-size: 1.45rem;
							font-weight: 700;
							margin: 0;
						}

						& > h2 {
							overflow: hidden;

							font-size: 1.25rem;
							font-weight: 550;
							margin: 0;
							opacity: 80%;
						}
					}

					&:has(.context-menu) {
						& .options ion-item > ion-label {
							display: flex;
							flex-direction: column;
						}

						& .song-details {
							& > h1 {
								opacity: 80%;
							}

							& > h2 {
								opacity: 50%;
							}
						}
					}
				}

				& > .time-control,
				& > .volume-control {
					display: flex;
					flex-direction: column;
					align-items: center;
					justify-content: center;
					opacity: 80%;

					transition:
						transform,
						opacity,
						550ms cubic-bezier(0.175, 0.885, 0.32, 1.075);

					transform-origin: bottom center;
					&:has(> ion-range:active) {
						transform: scaleX(102%);
						opacity: 100%;
					}

					& > ion-range {
						width: 100%;

						transition: transform 550ms cubic-bezier(0.175, 0.885, 0.32, 1.075);
						transform-origin: bottom center;
						&:active {
							transform: scaleY(115%);
						}

						--bar-background: color-mix(in srgb, white 50%, transparent);
						--bar-background-active: white;
						--bar-border-radius: 8px;
						--bar-height: 8px;
						--knob-size: 0;

						&::part(bar) {
							top: 0;
							transition: height 350ms cubic-bezier(0.175, 0.885, 0.32, 1.075);
						}

						&::part(bar-active) {
							top: 0;
							z-index: -1;
						}

						&:hover {
							--bar-height: 10px;
						}

						&:active {
							--bar-height: 12px;
						}
					}

					& > .time-control-labels,
					& > .volume-control-labels {
						margin-top: 0;
						width: 100%;
						display: flex;
						align-items: center;
						justify-content: space-between;

						& > p {
							margin-top: 0;
							letter-spacing: 0px;
							font-weight: bold;
							font-size: 0.8rem;
							font-feature-settings: "tnum";
							font-variant-numeric: tabular-nums;
						}
					}

					& > .volume-control-labels {
						justify-content: center;
					}
				}

				& > .player-controls {
					display: flex;
					align-items: center;
					justify-content: space-evenly;

					& > ion-button {
						transition:
							background-color,
							transform,
							500ms ease-out;
						border-radius: 9999px;

						&:active {
							transform: scale(80%);
							background-color: rgb(255 255 255 / 30%);
						}

						& > ion-icon {
							padding: 16px;
							color: white;
						}
					}
				}

				& > .player-actions {
					display: flex;
					align-items: center;
					justify-content: space-evenly;
					padding-top: 8px;

					& > ion-button {
						opacity: 70%;

						& > ion-icon {
							color: white;
						}
					}

					& > .toggled {
						--background: white;
						--border-radius: 12px;
						& > ion-icon {
							color: black;
						}
					}
				}
			}
		}
	}
}
</style>
