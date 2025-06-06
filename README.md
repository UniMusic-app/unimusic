<p align="center">
<img width="256" height="256" src="./assets/Icon-Rounded-Shadow-632x632.png" alt="UniMusic logo, a musical slur resembling smiley face" />
</p>
<h1 align="center"> UniMusic</h1>

Unified cross-platform music player.

## Demo showcase

https://github.com/user-attachments/assets/29bd54d2-f7f3-44c9-bfcb-54f1a88080ab

## Roadmap

Development is currently prioritized for iOS and macOS, however first stable release should also work on Android, Linux and Windows.

- ✅ - Basically ready
- 🟧 - Partially done
- 🟥 - Not yet added
- ❓ - Unknown if it will be added

| Service     | Status | Notes                                |
| ----------- | :----: | ------------------------------------ |
| MusicKit    |   ✅   |                                      |
| YouTube     |   ✅   | Age restricted content does not work |
| Local media |   ✅   |                                      |
| Deezer      |   ❓   |                                      |
| Jellyfin    |   ❓   |                                      |
| Funkwhale   |   ❓   |                                      |

| Feature               | Status | Notes                                       |
| --------------------- | :----: | ------------------------------------------- |
| Unified search        |   ✅   |                                             |
| Unified playlists     |   ✅   |                                             |
| Media synchronisation |   ✅   | Not tested on Windows                       |
| Unified library       |   🟧   | Missing YouTube support and UI to add items |
| Metadata tagging      |   🟥   | Manual metadata edition is supported        |
| Lyrics                |   🟥   |                                             |

## Development

### Conditional service bundling

`SERVICE_{LOCAL,MUSICKIT,YOUTUBE}` environment variables can be used to conditonally toggle bundling music services.\
All of them are set to `true` by default, meaning they are enabled.

### Shared

These steps are needed for every platform to work properly

1. Make sure you have all dependencies required to build the app:
   - Package manager: [pnpm](https://pnpm.io).
   - Make sure you have downloaded all prerequisites for:
     - [Capacitor](https://capacitorjs.com/docs/getting-started/environment-setup)
     - [Ionic](https://ionicframework.com/docs/intro/environment)
2. Place your [MusicKit Developer Token](https://developer.apple.com/documentation/applemusicapi/generating_developer_tokens) in corresponding files:
   - /.example.env ⇢ /.env
3. Setup ionic and install dependencies

```sh
pnpm install -g @ionic/cli          # Install ionic cli globally
ionic config set -g npmClient pnpm  # Make ionic use pnpm
pnpm install                        # Install all project dependencies
```

### Web

```sh
ionic serve             # Run the development server
ionic serve --external  # add --external if you want to host it to other devices on your network
ionic build             # Build the web app into dist/web
```

### Electron

1. If you intend to use DRM content via MusicKit in Electron you need to sign the electron application with VMP certificate, read more:
   - [Electron for Content Security VMP signing](https://github.com/castlabs/electron-releases/wiki/EVS)
   - [Signing VMP certificate during development](https://github.com/castlabs/electron-releases/wiki/FAQ#how-can-i-vmp-sign-my-application-during-development)
   - [My commit message explaining it a bit](https://github.com/Im-Beast/music-player/commit/cb5ba29462bd881608e62efef0417530b1cb6c8b)

```sh
pnpm electron-dev     # Run the app with development server
pnpm electron-build   # Build the electron app into dist/electron
pnpm electron-preview # Preview how the app will look like in production mode
```

### Mobile

> [!NOTE]
> MusicKit authorization on mobile requires you to already have Apple Music app installed.

#### iOS

> [!IMPORTANT]
> To run iOS app you will have to use physical device, as MusicKit is not supported in Simulator.

1. Build and open in Xcode

```sh
ionic capacitor build ios
```

2. Run on physical device

### Android

> [!NOTE]
> Unlike iOS you can use Android Virtual Devices (AVD) found in Android Studio or any other Emulator for that matter.

1. Place your [MusicKit Developer Token](https://developer.apple.com/documentation/applemusicapi/generating_developer_tokens) in:
   - /android/app/src/main/res/values/tokens.example.xml ⇢ /android/app/src/main/res/values/tokens.xml
2. Build or open the app

```sh
ionic capacitor open android # Build android and open Android Studio
ionic capacitor run android  # Or run android app directly in emulator
```

## Recommended IDE Setup

[VS Code](https://code.visualstudio.com/) + [Vue](https://marketplace.visualstudio.com/items?itemName=Vue.volar) + [Ionic](https://marketplace.visualstudio.com/items?itemName=ionic.ionic).
