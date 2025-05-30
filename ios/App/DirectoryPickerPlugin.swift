// src/ios/MultipleDirectoryPicker.swift

import Capacitor
import Foundation
import UIKit

@objc(DirectoryPicker)
public class DirectoryPicker: CAPPlugin, CAPBridgedPlugin, UIDocumentPickerDelegate {
    public let identifier = "DirectoryPickerPlugin"
    public let jsName = "DirectoryPicker"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "pickDirectory", returnType: CAPPluginReturnPromise),
    ]

    var currentCall: CAPPluginCall?
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

    @objc func pickDirectory(_ call: CAPPluginCall) {
        guard let viewController = bridge?.viewController else {
            return
        }

        DispatchQueue.main.async {
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
            documentPicker.delegate = self
            self.currentCall = call
            viewController.present(documentPicker, animated: true)
        }
    }

    public func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let call = currentCall else {
            return
        }

        let documentsPath = documentsDirectory!.path
        let validUrls = urls.map { $0.path }.filter {
            print("Path: \($0) | Root: \(documentsPath)")
            return $0.contains(documentsPath)
        }

        if validUrls.isEmpty {
            call.reject("You can only choose a directory within the App's Documents folder")
        } else {
            call.resolve([
                "path": validUrls[0]
                    .replacingOccurrences(of: "/private", with: "")
                    .replacingOccurrences(of: documentsPath, with: ""),
            ])
        }

        currentCall = .none
    }

    public func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        guard let call = currentCall else {
            return
        }

        call.reject("User cancelled directory selection")
        currentCall = .none
    }
}
