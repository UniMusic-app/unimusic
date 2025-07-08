<script lang="ts" setup>
import MiniMusicPlayer from "@/components/MiniMusicPlayer.vue";
import MusicPlayer from "@/components/MusicPlayer.vue";
import SidebarButton from "@/components/SidebarButton.vue";
import {
	IonApp,
	IonIcon,
	IonLabel,
	IonList,
	IonListHeader,
	IonMenu,
	IonRouterOutlet,
	IonSplitPane,
	IonTabBar,
	IonTabButton,
	IonTabs,
} from "@ionic/vue";
import { useMediaQuery } from "@vueuse/core";
import {
	albums as albumsIcon,
	albumsOutline as albumsOutlineIcon,
	people as artistsIcon,
	peopleOutline as artistsOutlineIcon,
	home as homeIcon,
	homeOutline as homeOutlineIcon,
	library as libraryIcon,
	musicalNotes as playlistsIcon,
	musicalNotesOutline as playlistsOutlineIcon,
	search as searchIcon,
	searchOutline as searchOutlineIcon,
	cog as settingsIcon,
	cogOutline as settingsOutlineIcon,
	musicalNote as songsIcon,
	musicalNoteOutline as songsOutlineIcon,
} from "ionicons/icons";

const mediumScreen = useMediaQuery("(min-width: 768px)");
</script>

<template>
	<ion-app>
		<ion-split-pane :when="mediumScreen" content-id="main-content">
			<ion-menu id="sidebar-menu" content-id="main-content">
				<ion-list lines="none" inset>
					<SidebarButton :icon="homeIcon" :outline-icon="homeOutlineIcon" href="/home">
						Home
					</SidebarButton>
					<SidebarButton :icon="searchIcon" :outline-icon="searchOutlineIcon" href="/search">
						Search
					</SidebarButton>
					<SidebarButton :icon="settingsIcon" :outline-icon="settingsOutlineIcon" href="/settings">
						Settings
					</SidebarButton>

					<ion-list-header>
						<ion-label>Library</ion-label>
					</ion-list-header>
					<SidebarButton
						:icon="playlistsIcon"
						:outline-icon="playlistsOutlineIcon"
						href="/library/playlists"
					>
						Playlists
					</SidebarButton>
					<SidebarButton :icon="albumsIcon" :outline-icon="albumsOutlineIcon" href="/library/albums">
						Albums
					</SidebarButton>
					<SidebarButton :icon="songsIcon" :outline-icon="songsOutlineIcon" href="/library/songs">
						Songs
					</SidebarButton>
					<SidebarButton :icon="artistsIcon" :outline-icon="artistsOutlineIcon" href="/library/artists">
						Artists
					</SidebarButton>
				</ion-list>
			</ion-menu>

			<div id="main-content">
				<ion-tabs>
					<ion-router-outlet />

					<div slot="bottom">
						<MusicPlayer />
						<MiniMusicPlayer :floating="mediumScreen" />

						<ion-tab-bar v-if="!mediumScreen">
							<ion-tab-button tab="home" href="/home">
								<ion-icon aria-hidden="true" :icon="homeIcon" />
								<ion-label>Home</ion-label>
							</ion-tab-button>

							<ion-tab-button tab="search" href="/search">
								<ion-icon aria-hidden="true" :icon="searchIcon" />
								<ion-label>Search</ion-label>
							</ion-tab-button>

							<ion-tab-button tab="library" href="/library">
								<ion-icon aria-hidden="true" :icon="libraryIcon" />
								<ion-label>Library</ion-label>
							</ion-tab-button>

							<ion-tab-button tab="sync" href="/settings">
								<ion-icon aria-hidden="true" :icon="settingsIcon" />
								<ion-label>Settings</ion-label>
							</ion-tab-button>
						</ion-tab-bar>
					</div>
				</ion-tabs>
			</div>
		</ion-split-pane>
	</ion-app>
</template>

<style global>
/** Fix for ion-router-outlet becoming too short while modal with presenting-element is opened */
ion-split-pane:has(~ ion-modal[id^="ion-overlay"]) ion-router-outlet {
	height: 100vh;
}
</style>

<style scoped>
#sidebar-menu {
	--background: var(--ion-background-color-step-100, #fafafa);
	width: max-content;

	& > ion-list {
		margin: 0;
		padding: 16px;

		height: 100%;
		background: transparent;

		& > ion-item {
			--background: transparent;
			border-radius: 12px;
			margin: 8px;

			&.active {
				--background: var(--ion-background-color-step-150, #ffffff);
				box-shadow: 0 0 12px #0002;
				font-weight: bold;
			}
		}
	}
}

@keyframes fade-in {
	from {
		opacity: 0%;
	}

	40% {
		opacity: 0%;
	}

	to {
		opacity: 100%;
	}
}

ion-app {
	animation: fade-in 400ms forwards;
}

#main-content {
	width: 100%;
	height: 100%;
}
</style>
