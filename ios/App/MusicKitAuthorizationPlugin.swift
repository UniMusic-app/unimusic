import Capacitor
import MusicKit

@objc(MusicKitAuthorizationPlugin)
public class MusicKitAuthorizationPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "MusicKitAuthorizationPlugin"
    public let jsName = "MusicKitAuthorization"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "authorize", returnType: CAPPluginReturnPromise),
    ]

    @objc func authorize(_ call: CAPPluginCall) {
        Task {
            let status = await MusicAuthorization.request()
            switch status {
            case .authorized:
                do {
                    let developerToken = try await DefaultMusicTokenProvider().developerToken(options: MusicTokenRequestOptions.ignoreCache)
                    let musicUserToken = try await DefaultMusicTokenProvider().userToken(for: developerToken, options: MusicTokenRequestOptions.ignoreCache)

                    call.resolve([
                        "developerToken": developerToken,
                        "musicUserToken": musicUserToken,
                    ])
                } catch {
                    call.reject("Failed to retrieve MusicKit tokens: \(error)")
                }
            case .notDetermined:
                call.reject("User has not made a choice yet")
            case .restricted:
                call.reject("Access to MusicKit on this device is restricted")
            case .denied:
                call.reject("User has denied access to MusicKit")
            default:
                call.reject("Unknown error: \(status)")
            }
        }
    }
}
