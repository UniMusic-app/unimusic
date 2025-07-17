declare global {
	namespace MusicKit {
		/**
		 * A response object composed of paginated resource objects for the request.
		 * @see https://developer.apple.com/documentation/applemusicapi/paginatedresourcecollectionresponse
		 */
		interface PaginatedResourceCollectionResponse {
			/** A paginated collection of resources for the request. */
			data: Resource[];
			/** A relative cursor to fetch the next paginated collection of resources for the request if more exist. */
			next?: string;
		}
	}
}

export {};
