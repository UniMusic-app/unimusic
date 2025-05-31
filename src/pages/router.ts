import { createRouter, createWebHistory } from "@ionic/vue-router";
import { RouteRecordRaw } from "vue-router";

import HomePage from "@/pages/Home/HomePage.vue";
import SearchPage from "@/pages/Search/SearchPage.vue";

import AlbumPage from "@/pages/Library/Albums/Album/AlbumPage.vue";
import AlbumsPage from "@/pages/Library/Albums/AlbumsPage.vue";
import ArtistPage from "@/pages/Library/Artists/Artist/ArtistPage.vue";
import ArtistsPage from "@/pages/Library/Artists/ArtistsPage.vue";
import LibraryPage from "@/pages/Library/LibraryPage.vue";
import PlaylistPage from "@/pages/Library/Playlists/Playlist/PlaylistPage.vue";
import PlaylistsPage from "@/pages/Library/Playlists/PlaylistsPage.vue";
import SongPage from "@/pages/Library/Songs/Song/SongPage.vue";
import SongsPage from "@/pages/Library/Songs/SongsPage.vue";
import ArtistsSongsPage from "./Library/Artists/Artist/ArtistsSongsPage.vue";
import SyncPage from "./Sync/SyncPage.vue";

const routes: RouteRecordRaw[] = [
	{ path: "/", redirect: "/home" },
	{ path: "/home", name: "Home", component: HomePage },
	{ path: "/search", name: "Search", component: SearchPage },

	{ path: "/library", name: "Library", component: LibraryPage },

	{ path: "/sync", name: "Sync", component: SyncPage },

	{ path: "/library/songs", name: "Songs", component: SongsPage },
	{ path: "/items/songs/:songType/:songId", name: "Song", component: SongPage },

	{ path: "/library/artists", name: "Artists", component: ArtistsPage },
	{ path: "/items/artists/:artistType/:artistId", name: "Artist", component: ArtistPage },
	{
		path: "/items/artists/:artistType/:artistId/songs",
		name: "Artists Songs",
		component: ArtistsSongsPage,
	},

	{ path: "/library/albums", name: "Albums", component: AlbumsPage },
	// Album page provided as is
	{ path: "/items/albums/album/:albumType/:albumId", name: "Album", component: AlbumPage },
	// Album page provided by song
	{ path: "/items/albums/song/:songType/:songId", name: "Songs Album", component: AlbumPage },

	{ path: "/library/playlists", name: "Playlists", component: PlaylistsPage },
	{ path: "/items/playlists/:id", name: "Playlist", component: PlaylistPage },
];

const router = createRouter({
	history: createWebHistory(import.meta.env.BASE_URL),
	routes,
});

export default router;
