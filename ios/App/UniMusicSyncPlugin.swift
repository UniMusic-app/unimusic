import Capacitor
import UniformTypeIdentifiers
import UniMusicSync

@objc(UniMusicSyncPlugin)
public class UniMusicSyncPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "UniMusicSyncPlugin"
    public let jsName = "UniMusicSync"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "createNamespace", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "deleteNamespace", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getAuthor", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getNodeId", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getFiles", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "writeFile", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "deleteFile", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "readFile", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "readFileHash", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "share", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "export", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "exportHash", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "import", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sync", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reconnect", returnType: CAPPluginReturnPromise),
    ]

    public private(set) var uniMusicSync: UniMusicSync? = .none

    deinit {
        if let uniMusicSync {
            Task {
                try? await uniMusicSync.shutdown()
            }
        }
    }

    override public func load() {
        Task {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let syncPath = documentsPath.appendingPathComponent("UniMusicSync")
            do {
                uniMusicSync = try await UniMusicSync(syncPath.path)
                print("Initialized UniMusicSync")
            } catch {
                print("Failed to initialize UniMusicSync: \(error)")
            }
        }
    }

    @objc public func createNamespace(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        Task {
            do {
                let namespace = try await uniMusicSync.createNamespace()
                call.resolve([
                    "namespace": namespace,
                ])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func deleteNamespace(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let namespace = call.getString("namespace") else {
            call.reject("You must provide a 'namespace' option")
            return
        }

        Task {
            do {
                try await uniMusicSync.deleteNamespace(namespace: namespace)
                call.resolve()
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func getAuthor(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        Task {
            do {
                let author = try await uniMusicSync.getAuthor()
                call.resolve([
                    "author": author,
                ])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func getNodeId(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        Task {
            let nodeId = await uniMusicSync.getNodeId()
            call.resolve([
                "nodeId": nodeId,
            ])
        }
    }

    @objc public func getFiles(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let namespace = call.getString("namespace") else {
            call.reject("You must provide a 'namespace' option")
            return
        }

        Task {
            do {
                let files = try await uniMusicSync.getFiles(namespace)

                var filesObject: PluginCallResultData = [:]
                for entry in files {
                    if entry.isEmpty() {
                        continue
                    }

                    let key = entry.key()
                    filesObject[key] = [
                        "key": key,
                        "author": entry.author(),
                        "timestamp": entry.timestamp(),
                        "contentHash": entry.contentHash(),
                        "contentLen": entry.contentLen(),
                    ]
                }

                call.resolve(filesObject)
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func writeFile(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let namespace = call.getString("namespace") else {
            call.reject("You must provide a 'namespace' option")
            return
        }

        guard let syncPath = call.getString("syncPath") else {
            call.reject("You must provide a 'syncPath' option")
            return
        }

        guard let sourcePath = call.getString("sourcePath"),
              let sourcePathUrl = URL(string: sourcePath)
        else {
            call.reject("You must provide a valid file url for 'sourcePath' option")
            return
        }

        Task {
            do {
                let data = try Data(contentsOf: sourcePathUrl)
                let fileHash = try await uniMusicSync.writeFile(
                    namespace,
                    syncPath,
                    data
                )
                call.resolve([
                    "fileHash": fileHash,
                ])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func deleteFile(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let namespace = call.getString("namespace") else {
            call.reject("You must provide a 'namespace' option")
            return
        }

        guard let syncPath = call.getString("syncPath") else {
            call.reject("You must provide a 'syncPath' option")
            return
        }

        Task {
            do {
                let tombstoneHash = try await uniMusicSync.deleteFile(namespace, syncPath)
                call.resolve()
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func readFile(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let namespace = call.getString("namespace") else {
            call.reject("You must provide a 'namespace' option")
            return
        }

        guard let syncPath = call.getString("syncPath") else {
            call.reject("You must provide a 'syncPath' option")
            return
        }

        Task {
            do {
                let data = try await uniMusicSync.readFile(namespace, syncPath)
                let dataType = UTType(filenameExtension: (syncPath as NSString).pathExtension)
                let server = HTTPResponseServer(body: data, type: dataType)
                let url = try await server.start()
                call.resolve([
                    "url": url.absoluteString,
                ])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func readFileHash(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let fileHash = call.getString("fileHash") else {
            call.reject("You must provide a 'fileHash' option")
            return
        }

        Task {
            do {
                let data = try await uniMusicSync.readFileHash(fileHash)
                let server = HTTPResponseServer(body: data, type: .data)
                let url = try await server.start()
                call.resolve([
                    "url": url,
                ])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func export(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let namespace = call.getString("namespace") else {
            call.reject("You must provide a 'namespace' option")
            return
        }

        guard let syncPath = call.getString("syncPath") else {
            call.reject("You must provide a 'syncPath' option")
            return
        }

        guard let destinationPath = call.getString("destinationPath"),
              let _ = URL(string: destinationPath)
        else {
            call.reject("You must provide a valid file url for 'destinationPath' option")
            return
        }

        Task {
            do {
                try await uniMusicSync.export(namespace, syncPath, destinationPath)
                call.resolve()
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func exportHash(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let fileHash = call.getString("fileHash") else {
            call.reject("You must provide a 'fileHash' option")
            return
        }

        guard let destinationPath = call.getString("destinationPath"),
              let _ = URL(string: destinationPath)
        else {
            call.reject("You must provide a valid file url for 'destination' option")
            return
        }

        Task {
            do {
                try await uniMusicSync.exportHash(fileHash, destinationPath)
                call.resolve()
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func share(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let namespace = call.getString("namespace") else {
            call.reject("You must provide a 'namespace' option")
            return
        }

        Task {
            do {
                let ticket = try await uniMusicSync.share(namespace)
                call.resolve([
                    "ticket": ticket,
                ])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func `import`(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let ticket = call.getString("ticket") else {
            call.reject("You must provide a 'namespaceId' option")
            return
        }

        Task {
            do {
                let namespace = try await uniMusicSync.import(ticket)
                call.resolve([
                    "namespace": namespace,
                ])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func sync(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        guard let namespace = call.getString("namespace") else {
            call.reject("You must provide a 'namespace' option")
            return
        }

        Task {
            do {
                try await uniMusicSync.sync(namespace)
                call.resolve()
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc public func reconnect(_ call: CAPPluginCall) {
        guard let uniMusicSync else {
            call.reject("UniMusicSync is not initialized")
            return
        }

        Task {
            await uniMusicSync.reconnect()
            call.resolve()
        }
    }
}
