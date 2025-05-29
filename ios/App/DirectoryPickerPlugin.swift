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
        guard let viewController = self.bridge?.viewController else {
            return
        }

        DispatchQueue.main.async {
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
            documentPicker.delegate = self
            self.currentCall = call
            viewController.present(documentPicker, animated: true)
        }
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let call = self.currentCall else {
            return
        }

        let documentsPath = self.documentsDirectory!.path
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

        self.currentCall = .none
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard let call = self.currentCall else {
            return
        }

        call.reject("User cancelled directory selection")
        self.currentCall = .none
    }
}
