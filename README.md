# Music player (name is wip)

Unified cross-platform music player.

## Demo showcase

https://github.com/user-attachments/assets/ef20a3ac-5b66-4002-a10e-615af8d44119

## Roadmap

Development is currently prioritized for iOS and macOS, however first stable release should also work on Android, Linux and Windows.

<table>
	<tr>
		<th colspan="2">Feature</th>
		<th>Estimated timeline</th>
	</tr>
	<tr>
		<td>MusicKit</td>
		<td>
			Support Apple Music via MusicKit to allow legal streaming of music on
			every platform.
		</td>
		<td>14th January 2025</td>
	</tr>
	<tr>
		<td>Deezer</td>
		<td>Alike MusicKit</td>
		<td>indeterminate*</td>
	</tr>
	<tr>
		<td rowspan="2">Local media</td>
		<td>Playing local audio tracks</td>
    <td>28th January 2025</td>
	</tr>
  <tr>
	  <td>Local device discovery with syncing media between devices</td>
    <td>May 2025</td>
  </tr>
	<tr>
		<td>YouTube</td>
		<td>Playing YouTube media</td>
		<td>14th February 2025</td>
	</tr>
	<tr>
		<td rowspan="2">Unified search and playlists</td>
		<td>Storing songs from multiple platforms in singular playlists</td>
		<td rowspan="2">February-March 2025</td>
	</tr>
	<tr>
		<td>Search for a song/album across platforms</td>
	</tr>
  <tr>
    <td>Metadata tagging</td>
    <td>
      Simple hosting service storing
      <ul>
        <li>Lyrics</li>
        <li>Cover albums</li>
        <li>Albums</li>
        <li>Track details (Artist, Year, etc.)</li>
      </ul>
      Such hosting will cache the metadata obtained either from MusicKit or
      Last.fm and forward it to the user
    </td>
    <td>April 2025</td>
  </tr>
  <tr>
    <td>Playlist synchronization</td>
    <td>
      Simple service to which user can log in that stores all the playlist data
      and syncs them between devices
    </td>
    <td>indeterminate*</td>
  </tr>
  <tr>
    <td>Decentralized media</td>
    <td>Seeding, leeching and streaming torrents</td>
    <td>indeterminate*</td>
  </tr>
</table>

Dates attributed to each features are a subject to change as they are a very rough estimates at a very early point in development.
Debugging, life-related things, app design and such might affect them.
I will try to update the roadmap as the development progresses.

\* – Features considered "optional", unclear whether they will materialize

## Run locally

> [!IMPORTANT]
> To run iOS app you will have to use physical device, as MusicKit is not supported in Simulator.
> This is not the case for Android, where you can use Android Virtual Devices (AVD) in Android Studio or any other Emulator

> [!NOTE]
> MusicKit authorization on mobile (both Android and iOS) requires you to already have Apple Music app installed.

1. Make sure you have all dependencies required to build the app:
	- Package manager: [pnpm](https://pnpm.io).
	- Make sure you have downloaded all prerequisites for:
 		- [Capacitor](https://capacitorjs.com/docs/getting-started/environment-setup)
		- [Ionic](https://ionicframework.com/docs/intro/environment)
2. Place your [MusicKit Developer Token](https://developer.apple.com/documentation/applemusicapi/generating_developer_tokens) in corresponding files:
	- /.example.env ⇢ /.env
	- /android/app/src/main/res/values/tokens.example.xml ⇢ /android/app/src/main/res/values/tokens.xml
3. Install the project dependencies and run the app
```sh
pnpm install -g @ionic/cli # install ionic cli globally
ionic config set -g npmClient pnpm # Make ionic use pnpm

pnpm install
ionic serve # Preview the app in browser
ionic capacitor build {ios,android} # Build on mobile, then run them in their respective IDE's
# or
ionic capacitor run android # Run android app directly on android
```

## Recommended IDE Setup

[VS Code](https://code.visualstudio.com/) + [Vue](https://marketplace.visualstudio.com/items?itemName=Vue.volar) + [Ionic](https://marketplace.visualstudio.com/items?itemName=ionic.ionic).
