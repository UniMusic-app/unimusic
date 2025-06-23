// src/ios/MultipleDirectoryPicker.swift

import Capacitor
import Foundation
import UIKit
import ChromaSwift

@objc(Chromaprint)
public class Chromaprint: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ChromaprintPlugin"
    public let jsName = "Chromaprint"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "fingerprint", returnType: CAPPluginReturnPromise),
    ]

    @objc func fingerprint(_ call: CAPPluginCall) {
        guard let filePath = call.getString("filePath"),
        let fileUrl = URL(string: filePath) else {
            call.reject("You must provide a valid 'filePath' option")
            return
        }
    
        let exists = FileManager.default.fileExists(atPath: fileUrl.path)
        print("Path: \(filePath), URL: \(fileUrl), Exists: \(exists)")
        
        Task {
            do {
                let fingerprint = try AudioFingerprint(from: fileUrl, algorithm: .test2)
                call.resolve([
                    "fingerprint": fingerprint.base64
                ])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }
}
