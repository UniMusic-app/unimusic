/**
 * This module gets ran on the initialization of Electron
 * @module
 */

import type {
	AuthorId,
	DocTicket,
	FileInfo,
	Hash,
	NamespaceId,
	NodeId,
} from "@/plugins/UniMusicSync";

declare global {
	interface $ElectronBridge {
		musicKit: {
			authorize(): Promise<string | undefined>;
		};

		fetch: (
			input: string,
			init: unknown,
		) => Promise<{
			url: string;
			status: number;
			statusText: string;
			body: Uint8Array;
			headers: Record<string, string>;
		}>;

		fileSystem: {
			readFile: (path: string) => Promise<Uint8Array>;
			writeFile: (path: string, data: Uint8Array) => Promise<void>;
			statFile: (
				path: string,
			) => Promise<{ type: "file" | "directory"; mtime: number; ctime: number; size: number }>;
			pickDirectory: () => Promise<string>;
			traverseDirectory: (path: string) => Promise<string[]>;
			getMusicPath: () => Promise<string>;
			getUserDataPath: () => Promise<string>;
		};

		uniMusicSync: {
			initialize(): Promise<void>;

			createNamespace(): Promise<NamespaceId>;
			deleteNamespace(namespace: NamespaceId): Promise<void>;

			getAuthor(): Promise<AuthorId>;
			getNodeId(): Promise<NodeId>;

			getFiles(namespace: NamespaceId): Promise<FileInfo[]>;
			writeFile(namespace: NamespaceId, sourcePath: string, syncPath: string): Promise<Hash>;
			deleteFile(namespace: NamespaceId, syncPath: string): Promise<number>;
			readFile(namespace: NamespaceId, syncPath: string): Promise<Uint8Array>;
			readFileHash(fileHash: Hash): Promise<Uint8Array>;

			export(namespace: NamespaceId, syncPath: string, destinationPath: string): Promise<void>;
			exportHash(fileHash: Hash, destinationPath: string): Promise<void>;

			share(namespace: NamespaceId): Promise<DocTicket>;
			import(ticket: DocTicket): Promise<NamespaceId>;

			sync(namespace: NamespaceId): Promise<void>;
			reconnect(): Promise<void>;
		};
	}

	// eslint-disable-next-line no-var
	var $ElectronBridge: $ElectronBridge | undefined;

	interface ElectronBridge extends $ElectronBridge {
		fetchShim: typeof globalThis.fetch;
	}
	// eslint-disable-next-line no-var
	var ElectronBridge: ElectronBridge | undefined;
}

globalThis.ElectronBridge = {
	...$ElectronBridge!,
	/**
	 * Fetch with Electron-sided implementation to work-around CORS without disabling Web Security
	 */
	async fetchShim(input, init): Promise<globalThis.Response> {
		let url: string;
		let options: RequestInit | undefined;

		const headers: Record<string, string> = {};
		if (input instanceof Request) {
			Object.assign(headers, Object.fromEntries(input.headers.entries()));
		}
		if (init?.headers instanceof Headers) {
			for (const [key, value] of init.headers.entries()) {
				headers[key] = value;
			}
		}

		if (input instanceof Request) {
			url = input.url;

			options = {
				body: await input.text(),
				cache: input.cache,
				credentials: input.credentials,
				integrity: input.integrity,
				keepalive: input.keepalive,
				method: input.method,
				mode: input.mode,
				redirect: input.redirect,
				referrer: input.referrer,
				referrerPolicy: input.referrerPolicy,
				...init,
				headers,
			};
		} else {
			url = typeof input === "string" ? input : input.toString();
			options = { ...init, headers };
		}

		const nativeResponse = await ElectronBridge!.fetch(url, options);

		return new Response(nativeResponse.body, {
			status: nativeResponse.status,
			statusText: nativeResponse.statusText,
			headers: nativeResponse.headers,
		});
	},
};

/** Prevent object from being overwritten */
Object.defineProperty(globalThis, "ElectronBridge", {
	writable: false,
	configurable: false,
	enumerable: false,
	value: Object.freeze(globalThis.ElectronBridge),
});

export {};
