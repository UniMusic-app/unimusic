import { registerPlugin } from "@capacitor/core";

export interface DirectoryPickerPlugin {
	pickDirectory(): Promise<{ path: string }>;
}

const DirectoryPicker = registerPlugin<DirectoryPickerPlugin>("DirectoryPicker");

export default DirectoryPicker;
