declare global {
	// eslint-disable-next-line @typescript-eslint/no-namespace
	namespace MusicKit {
		class MusicKitInstance {
			readonly developerToken: string;
			musicUserToken?: string;
			isAuthorized: boolean;

			authorize(): string;
			unauthorize(): void;
		}

		function getInstance(): MusicKitInstance | undefined;
		function configure(...args: any): MusicKitInstance;
	}
}

export {};
