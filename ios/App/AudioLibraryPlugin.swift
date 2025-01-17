import Capacitor
import MediaPlayer

@objc(EchoPlugin)
public class AudioLibraryPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "AudioLibraryPlugin"
    public let jsName = "AudioLibrary"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "play", returnType: CAPPluginReturnNone),
        CAPPluginMethod(name: "pause", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "resume", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getCurrentPlaybackTime", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setCurrentPlaybackTime", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "currentSongId", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getSongs", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getAlbums", returnType: CAPPluginReturnPromise)
    ]
    
    // We use systemMusicPlayer, because applicationMusicPlayer doesn't allow background playback
    private let musicPlayer = MPMusicPlayerController.systemMusicPlayer;
    
    @objc func pause(_ call: CAPPluginCall) {
        musicPlayer.pause()
        call.resolve()
    }
    
    @objc func resume(_ call: CAPPluginCall) {
        if musicPlayer.playbackState == .paused {
            musicPlayer.play()
        }
        call.resolve()
    }
    
    @objc func getCurrentPlaybackTime(_ call: CAPPluginCall) {
        call.resolve([ "currentPlaybackTime": musicPlayer.currentPlaybackTime ]);
    }

    
    @objc func setCurrentPlaybackTime(_ call: CAPPluginCall) {
        guard let time = call.options["time"] as? Double else {
            call.reject("Failed to set currentPlaybackTime: missing time parameter")
            return
        }
        
        musicPlayer.currentPlaybackTime = time;
        call.resolve()
    }

    @objc func currentSongId(_ call: CAPPluginCall) {
        if let id = musicPlayer.nowPlayingItem?.persistentID {
            call.resolve([ "id": String(id) ])
        } else {
            call.resolve()
        }
    }
    
    @objc func play(_ call: CAPPluginCall) {
        guard let songId = call.options["id"] as? String else {
            call.reject("Failed to playSong: Missing id parameter");
            return
        }
        
        // Find the song from id
        let query = MPMediaQuery.songs();
        let predicate = MPMediaPropertyPredicate.init(
            value: songId,
            forProperty: MPMediaItemPropertyPersistentID
        );
        query.addFilterPredicate(predicate);
        
        if query.items == nil || query.items!.isEmpty {
            call.reject("Failed to playSong: Could not find song \(songId)")
            return
        }
        
        // We cant just set current item, instead we have to set the queue to the query containing that singular item
        musicPlayer.setQueue(with: query)
        musicPlayer.play();
        call.resolve();
    }
    
    @objc func getSongs(_ call: CAPPluginCall) {
        let songsQuery = MPMediaQuery.songs().items!
        var songs: [[String: Any?]] = [];
        for song in songsQuery {
            let base64Artwork = song.artwork?
                .image(at: CGSize(width: 256, height: 256))?
                .jpegData(compressionQuality: 0.8)?
                .base64EncodedString()
            
            songs.append([
                "id": String(song.persistentID),
                "title": song.title,
                "artist": song.artist,
                "genre": song.genre,
                "artwork": base64Artwork.map { "data:text/plain;base64,\($0)" },
                "duration": song.playbackDuration,
                "path": song.assetURL?.absoluteString
            ])
        }
        
        call.resolve(["songs": songs])
    }
    
    @objc func getAlbums(_ call: CAPPluginCall) {
        let albumsQuery = MPMediaQuery.albums().items!
        var albums: [[String: Any?]] = [];
        for album in albumsQuery {
            let base64Artwork = album.artwork?
                .image(at: CGSize(width: 256, height: 256))?
                .jpegData(compressionQuality: 0.8)?
                .base64EncodedString()
        
            albums.append([
                "id": album.albumPersistentID,
                "title": album.albumTitle,
                "artist": album.albumArtist,
                "genre": album.genre,
                "artwork": base64Artwork.map { "data:text/plain;base64,\($0)" },
            ])
        }
        
        call.resolve(["albums": albums])
    }
}
