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
import LyricsServicesSettingsPage from "./Settings/LyricsServices/LyricsServicesSettingsPage.vue";
import MetadataServicesSettingsPage from "./Settings/MetadataServices/MetadataServicesSettingsPage.vue";
import MusicServicesSettingsPage from "./Settings/MusicServices/MusicServicesSettingsPage.vue";
import SettingsPage from "./Settings/SettingsPage.vue";
import SyncImportPage from "./Settings/Sync/SyncImportPage.vue";
import SyncImportTicketPage from "./Settings/Sync/SyncImportTicketPage.vue";
import SyncNamespacesPage from "./Settings/Sync/SyncNamespacesPage.vue";
import SyncSettingsPage from "./Settings/Sync/SyncSettingsPage.vue";
import SyncSharePage from "./Settings/Sync/SyncSharePage.vue";
import SyncShareTicketPage from "./Settings/Sync/SyncShareTicketPage.vue";

const routes: RouteRecordRaw[] = [
	{ path: "/", redirect: "/home" },
	{ path: "/home", name: "Home", component: HomePage },
	{ path: "/search", name: "Search", component: SearchPage },

	{ path: "/library", name: "Library", component: LibraryPage },

	{ path: "/settings", name: "Settings", component: SettingsPage },
	{ path: "/settings/sync", name: "Sync Settings", component: SyncSettingsPage },
	{ path: "/settings/sync/import", name: "Sync Import", component: SyncImportPage },
	{
		path: "/settings/sync/import/ticket",
		name: "Sync Import Ticket",
		component: SyncImportTicketPage,
		props: (route) => ({
			method: route.query.method,
			directory: route.query.directory,
		}),
	},
	{ path: "/settings/sync/share", name: "Sync Share", component: SyncSharePage },
	{
		path: "/settings/sync/share/ticket",
		name: "Sync Share Ticket",
		component: SyncShareTicketPage,
		props: (route) => ({ ticket: route.query.ticket }),
	},
	{ path: "/settings/sync/namespaces", name: "Sync Namespaces", component: SyncNamespacesPage },
	{
		path: "/settings/services/music",
		name: "Music Services Settings",
		component: MusicServicesSettingsPage,
	},
	{
		path: "/settings/services/lyrics",
		name: "Lyrics Services Settings",
		component: LyricsServicesSettingsPage,
	},
	{
		path: "/settings/services/metadata",
		name: "Metadata Services Settings",
		component: MetadataServicesSettingsPage,
	},

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
	{ path: "/items/playlists/:playlistType/:playlistId", name: "Playlist", component: PlaylistPage },
];

const router = createRouter({
	history: createWebHistory(import.meta.env.BASE_URL),
	routes,
});

export default router;
