import { WebPlugin } from "@capacitor/core";
import { DirectoryPickerPlugin } from "../DirectoryPicker";

// Electron implementation of DirectoryPicker
export class DirectoryPicker extends WebPlugin implements DirectoryPickerPlugin {
	async pickDirectory(): Promise<{ path: string }> {
		const path = await ElectronBridge!.fileSystem.pickDirectory();
		return { path };
	}
}
