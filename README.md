# Music player (name is wip)

Unified cross-platform music player.

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

Package manager: `pnpm`.\
Make sure you have downloaded all [Capacitor](https://capacitorjs.com/docs/getting-started/environment-setup) and [Ionic](https://ionicframework.com/docs/intro/environment) Prerequisites.

```sh
pnpm install -g @ionic/cli # install ionic cli globally
ionic config set -g npmClient pnpm # Make ionic use pnpm

pnpm install
ionic servce # Run on desktop
ionic capacitor run {ios,android} # Run on mobile devices
```

## Recommended IDE Setup

[VS Code](https://code.visualstudio.com/) + [Vue](https://marketplace.visualstudio.com/items?itemName=Vue.volar) + [Ionic](https://marketplace.visualstudio.com/items?itemName=ionic.ionic).
