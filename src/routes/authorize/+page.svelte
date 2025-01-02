<script lang="ts">
	import { invoke } from "@tauri-apps/api/core";
	import { getCurrentPlatform, isMobile } from "$lib/utils";

	let authorized = $state(false);

	function runWithMusicKit(callback: () => void): void {
		if (globalThis.MusicKit) {
			callback();
		} else {
			document.addEventListener("musickitloaded", callback);
		}
	}

	async function configureMusicKit() {
		await MusicKit.configure({
			developerToken: import.meta.env.VITE_DEVELOPER_TOKEN,
			app: {
				name: "Music player",
				build: "0.0.1",
			},
		});
	}

	runWithMusicKit(async () => {
		const params = new URLSearchParams(window.location.href);
		const musicUserToken = params.get("musicUserToken");

		if (musicUserToken) {
			await configureMusicKit();
			// @ts-ignore It's not readonly
			MusicKit.getInstance().musicUserToken = musicUserToken;
		} else {
			await configureMusicKit();
		}

		authorized = MusicKit.getInstance().isAuthorized;
	});

	// MusicKit uses window.open for OAuth authentication
	// however Tauri does not support it for various reasons
	// so we just shim it
	window.open = (url, _target, features) => {
		invoke<string>("authorize_apple_music", {
			url: String(url),
		}).then((musicUserToken) => {
			// @ts-ignore not readonly
			MusicKit.getInstance().musicUserToken = musicUserToken;
			location.reload();
		});

		return {
			focus() {},
			closed: false,
		} as WindowProxy;
	};

	async function authorizeAppleMusic() {
		if (!MusicKit.getInstance()) {
			await configureMusicKit();
		}

		const music = MusicKit.getInstance();
		authorized = music.isAuthorized;
		const MUT = await music.authorize();
		console.log("MUUT", MUT);
	}
</script>

Platform: {getCurrentPlatform()}
Mobile: {isMobile()}

<p>
	You are {authorized ? "authorized" : "not authorized"}
</p>

<button onclick={authorizeAppleMusic}> Authorize Apple Music </button>
