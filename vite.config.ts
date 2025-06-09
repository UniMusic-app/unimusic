import legacy from "@vitejs/plugin-legacy";
import vue from "@vitejs/plugin-vue";

import { defineConfig } from "vite";
import capacitorConfig from "./capacitor.config";
import { sharedAlias, sharedBuild, sharedDefine } from "./shared.vite.config";

// https://vitejs.dev/config/
export default defineConfig({
	plugins: [vue(), legacy({ modernTargets: "defaults", modernPolyfills: true })],
	build: {
		outDir: capacitorConfig.webDir,
		cssTarget: "chrome109",
		...sharedBuild,
	},
	define: {
		__IS_ELECTRON__: false,
		...sharedDefine,
	},
	resolve: {
		alias: {
			...sharedAlias,
		},
	},
});
