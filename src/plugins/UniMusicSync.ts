import { isElectron } from "@/utils/os";
import { EitherType } from "@/utils/types";
import { registerPlugin } from "@capacitor/core";

export type NamespaceId = string;
export type AuthorId = string;
export type NodeId = string;
export type Hash = string;
export type DocTicket = string;

export interface FileInfo {
	key: string;
	author: AuthorId;
	timestamp: number;
	contentHash: Hash;
	contentLen: number;
}

export type DataResult = EitherType<[{ url: string }, { data: Uint8Array }]>;

export interface UniMusicSyncPlugin {
	createNamespace(): Promise<{ namespace: NamespaceId }>;
	deleteNamespace(options: { namespace: NamespaceId }): Promise<void>;

	getAuthor(): Promise<{ author: AuthorId }>;
	getNodeId(): Promise<{ nodeId: NodeId }>;

	getFiles(options: { namespace: NamespaceId }): Promise<Record<string, FileInfo>>;
	writeFile(options: {
		namespace: NamespaceId;
		sourcePath: string;
		syncPath: string;
	}): Promise<{ fileHash: Hash }>;
	deleteFile(options: { namespace: NamespaceId; syncPath: string }): Promise<void>;
	readFile(options: { namespace: NamespaceId; syncPath: string }): Promise<DataResult>;
	readFileHash(options: { fileHash: Hash }): Promise<DataResult>;

	export(options: {
		namespace: NamespaceId;
		syncPath: string;
		destinationPath: string;
	}): Promise<void>;
	exportHash(options: { fileHash: Hash; destinationPath: string }): Promise<void>;

	share(options: { namespace: NamespaceId }): Promise<{ ticket: DocTicket }>;
	import(options: { ticket: DocTicket }): Promise<{ namespace: NamespaceId }>;

	sync(options: { namespace: NamespaceId }): Promise<void>;
	reconnect(): Promise<void>;
}

const UniMusicSync = registerPlugin<UniMusicSyncPlugin>("UniMusicSync", {
	async web() {
		if (isElectron()) {
			const { UniMusicSync } = await import("./UniMusicSync/electron");
			const uniMusicSync = new UniMusicSync();
			await uniMusicSync.initialize();
			return uniMusicSync;
		}
	},
});

export default UniMusicSync;
