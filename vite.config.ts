import vue from "@vitejs/plugin-vue";
import { defineConfig } from "vite";
import capacitorConfig from "./capacitor.config";
import { sharedAlias, sharedBuild, sharedDefine } from "./shared.vite.config";

// https://vitejs.dev/config/
export default defineConfig({
	plugins: [vue()],
	build: {
		outDir: capacitorConfig.webDir,
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
