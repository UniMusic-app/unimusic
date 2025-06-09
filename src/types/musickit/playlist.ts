declare global {
	namespace MusicKit {
		interface PlaylistsQuery {
			/** Additional relationships to include in the fetch. */
			include?: (keyof PlaylistsRelationships)[];
			/** The localization to use, specified by a language tag. The possible values are in the supportedLanguageTags array belonging to the Storefront object specified by storefront. Otherwise, the default is defaultLanguageTag in Storefront. */
			l?: string;
			/** The views to activate for the resource. */
			views?: string[];
			/** A list of attribute extensions to apply to resources in the response. */
			extend?: string[];
		}

		/**
		 * The response to a playlists request.
		 * @see https://developer.apple.com/documentation/applemusicapi/playlistsresponse
		 */
		interface PlaylistsResponse {
			/** The Playlists included in the response for the request. */
			data: Playlists[];
		}

		/**
		 * A resource object that represents a playlist.
		 * @see https://developer.apple.com/documentation/applemusicapi/playlists
		 */
		interface Playlists {
			/** The identifier for the playlist. */
			id: string;
			/** This value is always playlists. */
			type: "playlists";
			/** The relative location for the playlist resource. */
			href: string;
			/** The attributes for the playlist. */
			attributes?: MusicKit.PlaylistsAttributes;

			/** The relationships for the playlist. */
			relationships?: PlaylistsRelationships;
			/** The relationship views for the album. */
			views?: MusicKit.ResourceViews;
		}

		interface PlaylistsRelationships {
			/**
			 * The curator that created the playlist. By default, curator includes identifiers only.
			 * Fetch limits: none
			 */
			curator: PlaylistsCuratorRelationships;
			/** Library playlist for a catalog playlist if added to library. */
			library: PlaylistsLibraryRelationships;
			/**
			 * The songs and music videos included in the playlist. By default, tracks includes objects.
			 * Fetch limits: 100 default, 300 maximum
			 */
			tracks: PlaylistsTracksRelationship;
		}

		/**
		 * A relationship from the playlist to its curator.
		 * @see https://developer.apple.com/documentation/applemusicapi/playlists/relationships-data.dictionary/playlistscuratorrelationship
		 */
		interface PlaylistsCuratorRelationships {
			/* A relative location for the relationship. */
			href?: string;
			/* A relative cursor to fetch the next paginated collection of resources in the relationship if more exist. */
			next?: string;
			/**
			 * The curator for the playlist.
			 * Possible types: Activities, AppleCurators, Curators
			 */
			data: unknown;
		}

		/**
		 * A relationship from the playlist to its library.
		 * @see https://developer.apple.com/documentation/applemusicapi/playlists/relationships-data.dictionary/playlistslibraryrelationship
		 */
		interface PlaylistsLibraryRelationships {
			/* A relative location for the relationship. */
			href?: string;
			/* A relative cursor to fetch the next paginated collection of resources in the relationship if more exist. */
			next?: string;
			/**
			 * The library for the playlist.
			 * Actual type is LibraryPlaylists[]
			 */
			data: Playlists[];
		}

		/**
		 * A relationship from the album to its tracks.
		 * @see https://developer.apple.com/documentation/applemusicapi/playlists/relationships-data.dictionary/playliststracksrelationship
		 */
		interface PlaylistsTracksRelationship {
			/* A relative location for the relationship. */
			href?: string;
			/* A relative cursor to fetch the next paginated collection of resources in the relationship if more exist. */
			next?: string;
			/**
			 * The ordered songs and music videos in the tracklist of the playlist.
			 * Possible types: MusicVideos, Songs
			 */
			data: MusicKit.Songs[];
		}

		/**
		 * The attributes for a library playlist creation request object.
		 * @see https://developer.apple.com/documentation/applemusicapi/libraryplaylistcreationrequest/attributes-data.dictionary
		 */
		interface LibraryPlaylistCreationRequestAttributes {
			name: string;
			description?: string;
		}

		/**
		 * A request to create a new playlist in a user’s library.
		 * @see https://developer.apple.com/documentation/applemusicapi/libraryplaylistcreationrequest
		 */
		interface LibraryPlaylistCreationRequest {
			attributes: LibraryPlaylistCreationRequestAttributes;
		}

		/**
		 * An object that represents a single track when added to a library playlist in a request.
		 */
		interface LibraryPlaylistTracksRequestData {
			/** The unique identifier of the library playlist track. */
			id: string;
			/** The type of the track to be added. The possible values are library-music-videos, library-songs, music-videos, or songs. */
			type: MusicKit.TrackType;
		}

		/**
		 * A request to add tracks to a library playlist.
		 * @see https://developer.apple.com/documentation/applemusicapi/libraryplaylisttracksrequest
		 */
		interface LibraryPlaylistTracksRequest {
			/**
			 * A list of dictionaries with information about the tracks to add.
			 */
			data: LibraryPlaylistTracksRequestData[];
		}

		/**
		 * The response to a library playlists request.
		 * @see https://developer.apple.com/documentation/applemusicapi/libraryplaylistsresponse
		 */
		interface LibraryPlaylistsResponse {
			/**
			 * The LibraryPlaylists included in the response for the request.
			 * Actual type is LibraryPlaylists[]
			 */
			data: Playlists[];
		}
	}
}

export {};
