declare global {
	namespace MusicKit {
		/**
		 * The response to a songs request.
		 * @see https://developer.apple.com/documentation/applemusicapi/songsresponse
		 */
		interface SongsResponse {
			/** The Songs included in the response for the request. */
			data: MusicKit.Songs[];
		}

		/**
		 * The response to a songs request.
		 * @see https://developer.apple.com/documentation/applemusicapi/librarysongsresponse
		 */
		interface LibrarySongsResponse {
			/** The LibrarySongs included in the response for the request. */
			data: MusicKit.LibrarySongs[];
		}
	}
}

export {};
