import { isElectron } from "@/utils/os";
import { registerPlugin } from "@capacitor/core";

export interface DirectoryPickerPlugin {
	pickDirectory(): Promise<{ path: string }>;
}

const DirectoryPicker = registerPlugin<DirectoryPickerPlugin>("DirectoryPicker", {
	async web() {
		if (isElectron()) {
			const { DirectoryPicker } = await import("./DirectoryPicker/electron");
			return new DirectoryPicker();
		}
	},
});

export default DirectoryPicker;
