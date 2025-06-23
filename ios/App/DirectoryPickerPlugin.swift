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
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    @objc func pickDirectory(_ call: CAPPluginCall) {
        guard let viewController = bridge?.viewController else {
            call.reject("Bridge does not have viewController")
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

        let documentsPath = documentsDirectory.absoluteString
        let validUrls = urls.map { $0.standardizedFileURL.absoluteString }.filter { $0.contains(documentsPath) }
        if validUrls.isEmpty {
            call.reject("You can only choose a directory within the App's Documents folder")
        } else {
            // Relative path to the Documents directory
            let relativePath = validUrls[0].replacingOccurrences(of: documentsPath, with: "").removingPercentEncoding!
            call.resolve([
                "path": relativePath
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
