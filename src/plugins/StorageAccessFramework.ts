import { registerPlugin } from "@capacitor/core";

export interface SAPFileInfo {
	name: string;
	type: "file" | "directory";
	size: number;
	mtime: number;
	uri: string;
}

export interface StorageAccessFrameworkPlugin {
	stat(options: { treeUri: string; path: string }): Promise<SAPFileInfo>;
	ensureFile(options: { treeUri: string; path: string }): Promise<{ uri: string }>;
	readdir(options: { treeUri: string; path: string }): Promise<{ files: SAPFileInfo[] }>;
}

const StorageAccessFramework =
	registerPlugin<StorageAccessFrameworkPlugin>("StorageAccessFramework");

export default StorageAccessFramework;
