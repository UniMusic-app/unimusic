declare global {
	namespace MusicKit {
		interface PersonalRecommendationResponse {
			/** The PersonalRecommendation resources included in the response for the request. */
			data: PersonalRecommendation[];
		}

		/**
		 * A resource object that represents recommended resources for a user calculated using their selected preferences
		 * @see https://developer.apple.com/documentation/applemusicapi/personalrecommendation
		 */
		interface PersonalRecommendation {
			/** The identifier for the recommendation. */
			id: string;
			/** This value must always be personal-recommendation. */
			type: "personal-recommendation";
			/** The relative location for the recommendation resource. */
			href: string;
			/** The attributes for the recommendation. */
			attributes?: PersonalRecommendationAttributes;
			/** The relationships for the playlist. */
			relationships?: PersonalRecommendationRelationships;
		}

		/**
		 * The attributes for a recommendation resource.
		 * @see https://developer.apple.com/documentation/applemusicapi/personalrecommendation/attributes-data.dictionary
		 */
		interface PersonalRecommendationAttributes {
			/**
			 * The type of recommendation. Possible values are:
			 * - music-recommendations – A recommendation for music content.
			 * - recently-played – A recommendation based on recently played content.
			 * - unknown – A generic recommendation type.
			 */
			kind: "music-recommendations" | "recently-played" | "unknown";
			/** The next date in UTC format for updating the recommendation. */
			nextUpdateDate: string;
			/** The localized title for the recommendation. */
			title?: { stringForDisplay: string; contentIds?: string[] };
			/** The localized reason for the recommendation. */
			reason?: string;
			/** The resource types supported by the recommendation. */
			resourceTypes: string[];
		}

		/**
		 * The relationships for a recommendation resource.
		 * @see https://developer.apple.com/documentation/applemusicapi/personalrecommendation/relationships-data.dictionary
		 */
		interface PersonalRecommendationRelationships {
			contents: PersonalRecommendationContentsRelationship;
		}

		/**
		 * A relationship from the recommendation to its recommended content.
		 * @see https://developer.apple.com/documentation/applemusicapi/personalrecommendation/relationships-data.dictionary/personalrecommendationcontentsrelationship
		 */
		interface PersonalRecommendationContentsRelationship {
			/** A relative location for the relationship. */
			href?: string;
			/** A relative cursor to fetch the next paginated collection of resources in the relationship if more exist. */
			next?: string;
			/** A list of recommended candidates that are a mixture of albums and playlists. */
			data: Resource[];
		}
	}
}

export {};
