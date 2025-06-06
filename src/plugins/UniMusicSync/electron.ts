import { WebPlugin } from "@capacitor/core";
import type {
	AuthorId,
	DataResult,
	DocTicket,
	FileInfo,
	Hash,
	NamespaceId,
	NodeId,
	UniMusicSyncPlugin,
} from "../UniMusicSync";

// Electron implementation of UniMusicSync
export class UniMusicSync extends WebPlugin implements UniMusicSyncPlugin {
	async initialize(): Promise<void> {
		await ElectronBridge!.uniMusicSync.initialize();
	}

	async createNamespace(): Promise<{ namespace: NamespaceId }> {
		const namespace = await ElectronBridge!.uniMusicSync.createNamespace();
		return { namespace };
	}

	async deleteNamespace(options: { namespace: NamespaceId }): Promise<void> {
		await ElectronBridge!.uniMusicSync.deleteNamespace(options.namespace);
	}

	async getAuthor(): Promise<{ author: AuthorId }> {
		const author = await ElectronBridge!.uniMusicSync.getAuthor();
		return { author };
	}

	async getNodeId(): Promise<{ nodeId: NodeId }> {
		const nodeId = await ElectronBridge!.uniMusicSync.getNodeId();
		return { nodeId };
	}

	async getFiles(options: { namespace: NamespaceId }): Promise<Record<string, FileInfo>> {
		const files = await ElectronBridge!.uniMusicSync.getFiles(options.namespace);
		const filesObject: Record<string, FileInfo> = {};
		for (const entry of files) {
			filesObject[entry.key] = entry;
		}
		return filesObject;
	}

	async writeFile(options: {
		namespace: NamespaceId;
		syncPath: string;
		sourcePath: string;
	}): Promise<{ fileHash: Hash }> {
		const fileHash = await ElectronBridge!.uniMusicSync.writeFile(
			options.namespace,
			options.syncPath,
			options.sourcePath,
		);
		return { fileHash };
	}

	async deleteFile(options: { namespace: NamespaceId; syncPath: string }): Promise<void> {
		await ElectronBridge!.uniMusicSync.deleteFile(options.namespace, options.syncPath);
	}

	async readFile(options: { namespace: NamespaceId; syncPath: string }): Promise<DataResult> {
		const data = await ElectronBridge!.uniMusicSync.readFile(options.namespace, options.syncPath);
		return { data };
	}

	async readFileHash(options: { fileHash: Hash }): Promise<DataResult> {
		const data = await ElectronBridge!.uniMusicSync.readFileHash(options.fileHash);
		return { data };
	}

	async export(options: {
		namespace: NamespaceId;
		syncPath: string;
		destinationPath: string;
	}): Promise<void> {
		await ElectronBridge!.uniMusicSync.export(
			options.namespace,
			options.syncPath,
			options.destinationPath,
		);
	}

	async exportHash(options: { fileHash: Hash; destinationPath: string }): Promise<void> {
		await ElectronBridge!.uniMusicSync.exportHash(options.fileHash, options.destinationPath);
	}

	async share(options: { namespace: NamespaceId }): Promise<{ ticket: DocTicket }> {
		const ticket = await ElectronBridge!.uniMusicSync.share(options.namespace);
		return { ticket };
	}

	async import(options: { ticket: DocTicket }): Promise<{ namespace: NamespaceId }> {
		const namespace = await ElectronBridge!.uniMusicSync.import(options.ticket);
		return { namespace };
	}

	async sync(options: { namespace: NamespaceId }): Promise<void> {
		await ElectronBridge!.uniMusicSync.sync(options.namespace);
	}

	async reconnect(): Promise<void> {
		await ElectronBridge!.uniMusicSync.reconnect();
	}
}
