import { registerPlugin } from "@capacitor/core";

export type NamespaceId = string;
export type AuthorId = string;
export type NodeId = string;
export type Hash = string;
export type DocTicket = string;

export interface Entry {
	key: string;
	author: AuthorId;
	timestamp: number;
	contentHash: Hash;
	contentLen: number;
}

export interface UniMusicSyncPlugin {
	createNamespace(): Promise<{ namespace: NamespaceId }>;

	getAuthor(): Promise<{ author: AuthorId }>;
	getNodeId(): Promise<{ nodeId: NodeId }>;

	getFiles(options: { namespace: NamespaceId }): Promise<Record<string, Entry>>;
	writeFile(options: {
		namespace: NamespaceId;
		sourcePath: string;
		syncPath: string;
	}): Promise<Hash>;
	readFile(options: { namespace: NamespaceId; syncPath: string }): Promise<{ url: string }>;
	readFileHash(options: { fileHash: Hash }): Promise<{ url: string }>;

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

const UniMusicSync = registerPlugin<UniMusicSyncPlugin>("UniMusicSync");

export default UniMusicSync;
