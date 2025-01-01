<script lang="ts">
  import { Window } from "@tauri-apps/api/window";
  import { getCurrentWebview, Webview } from "@tauri-apps/api/webview";
  import { LogicalSize, Size } from "@tauri-apps/api/dpi";
  import { webviewWindow } from "@tauri-apps/api";

  let authorized = $state(false);

  async function configureMusicKit() {
    try {
      await MusicKit.configure({
        developerToken: import.meta.env.VITE_DEVELOPER_TOKEN,
        app: {
          name: "Music player",
          build: "0.0.1",
        },
      });
    } catch (err) {
      console.error(err);
      return;
    }

    authorized = MusicKit.getInstance().isAuthorized;
  }

  document.addEventListener("musickitloaded", configureMusicKit);

  // MusicKit uses window.open for OAuth authentication
  // however Tauri does not support it for various reasons
  // Thankfully it also works by just redirecting to it (although it seems to not be documented anywhere)
  // Alternatively its also possible to open a new Webview window, however then it is required to "catch" the Music User Token and force-replace it manually, which seems iffy
  window.open = (url, _target, features) => {
    // On macOS on debug builds this might get stuck on the loading spinner
    // minimize and then maximize the app to un-stuck it
    // It's most likely related to the macOS TouchID logic to make the logging in seamless, as debug builds require logging in with email and password
    // While production builds does not freeze and allows touchid to be used
    // iOS doesn't seem to suffer from that issue
    window.location.href = String(url);

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
  }
</script>

<p>
  You are {authorized ? "authorized" : "not authorized"}
</p>

<button onclick={authorizeAppleMusic}> Authorize Apple Music </button>
