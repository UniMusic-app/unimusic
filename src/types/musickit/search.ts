declare global {
	namespace MusicKit {
		/**
		 * The response to a search request.
		 * @see https://developer.apple.com/documentation/applemusicapi/searchresponse
		 */
		interface SearchResponse {
			/** The results included in the response to a search request. */
			results: SearchResponseResults;
		}

		/**
		 * An object that represents the results of a catalog search query.
		 * @see https://developer.apple.com/documentation/applemusicapi/searchresponse
		 * @nonexhaustive
		 */
		interface SearchResponseResults {
			albums?: SearchResponseResultsAlbumsSearchResult;
			artists?: SearchResponseResultsArtistsSearchResult;
			playlists?: SearchResponseResultsPlaylistsSearchResult;
			songs?: SearchResponseResultsSongsSearchResult;
		}

		/**
		 * An object containing an albums’ search result.
		 * @see https://developer.apple.com/documentation/applemusicapi/searchresponse/results/albumssearchresult
		 */
		interface SearchResponseResultsAlbumsSearchResult {
			/** The resources for the search result. */
			data: MusicKit.Albums[];
			/** The relative location to fetch the search result. */
			href?: string;
			/** A relative cursor to fetch the next paginated collection of resources in the result, if more exist. */
			next?: string;
		}

		/**
		 * An object containing an artists’ search result.
		 * @see https://developer.apple.com/documentation/applemusicapi/searchresponse/results/artistssearchresult
		 */
		interface SearchResponseResultsArtistsSearchResult {
			/** The resources for the search result. */
			data: MusicKit.Artists[];
			/** The relative location to fetch the search result. */
			href?: string;
			/** A relative cursor to fetch the next paginated collection of resources in the result, if more exist. */
			next?: string;
		}

		/**
		 * An object containing an playlists' search result.
		 * @see https://developer.apple.com/documentation/applemusicapi/searchresponse/results/playlistssearchresult
		 */
		interface SearchResponseResultsPlaylistsSearchResult {
			/** The resources for the search result. */
			data: MusicKit.Playlists[];
			/** The relative location to fetch the search result. */
			href?: string;
			/** A relative cursor to fetch the next paginated collection of resources in the result, if more exist. */
			next?: string;
		}

		/**
		 * An object containing an songs' search result.
		 * @see https://developer.apple.com/documentation/applemusicapi/searchresponse/results/songssearchresult
		 */
		interface SearchResponseResultsSongsSearchResult {
			/** The resources for the search result. */
			data: MusicKit.Songs[];
			/** The relative location to fetch the search result. */
			href?: string;
			/** A relative cursor to fetch the next paginated collection of resources in the result, if more exist. */
			next?: string;
		}
	}
}

export {};
