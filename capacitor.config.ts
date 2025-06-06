import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
	appId: "app.unimusic",
	appName: "UniMusic",
	webDir: "dist/web",

	plugins: {
		// Patch fetch and XMLHttpRequest to use native libraries
		// This allows us to bypass CORS
		CapacitorHttp: { enabled: true },
		CapacitorCookies: { enabled: true },
	},

	// There is no way to just exclude plugins for some platforms so we have to do this:
	includePlugins: [
		"@capacitor/app",
		"@capacitor/filesystem",
		"@capacitor/haptics",
		"@capacitor/keyboard",
		"@capacitor/preferences",
		"@capacitor/status-bar",
		"@capacitor/barcode-scanner",
		"@capacitor/share",
	],
	android: {
		adjustMarginsForEdgeToEdge: "auto",
		includePlugins: [
			"@capacitor/app",
			"@capacitor/filesystem",
			"@capacitor/haptics",
			"@capacitor/keyboard",
			"@capacitor/preferences",
			"@capacitor/status-bar",
			"@capacitor/barcode-scanner",
			"@capacitor/share",
			"capacitor-music-controls-plugin",
		],
	},
};

export default config;
