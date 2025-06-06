import vue from "@vitejs/plugin-vue";
import type { ElectronViteConfig } from "electron-vite";
import { sharedAlias, sharedBuild, sharedDefine } from "./shared.vite.config";

export default {
	main: {
		build: {
			emptyOutDir: true,
			outDir: "./dist/electron/main",
			lib: {
				entry: "./electron/main.ts",
			},
			rollupOptions: {
				external: ["@unimusic/sync"],
			},
		},
	},
	preload: {
		build: {
			emptyOutDir: false,
			outDir: "./dist/electron/preload",
			lib: {
				entry: "./electron/preload.cjs",
			},
			rollupOptions: {
				output: {
					format: "cjs",
				},
			},
		},
	},
	renderer: {
		plugins: [vue()],
		root: ".",
		build: {
			emptyOutDir: false,
			outDir: "./dist/electron/renderer",
			rollupOptions: { input: "./index.html" },
			...sharedBuild,
		},
		define: {
			__IS_ELECTRON__: true,
			...sharedDefine,
		},
		resolve: {
			alias: {
				...sharedAlias,
			},
		},
	},
} satisfies ElectronViteConfig;
