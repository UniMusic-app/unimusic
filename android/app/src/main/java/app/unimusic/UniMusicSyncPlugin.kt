package app.unimusic

import android.net.Uri
import android.os.Environment
import androidx.documentfile.provider.DocumentFile
import app.unimusic.sync.UniMusicSync
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

@Suppress("unused")
@CapacitorPlugin(name = "UniMusicSync")
class UniMusicSyncPlugin : Plugin() {
    private val appJob = SupervisorJob()
    private val appScope = CoroutineScope(Dispatchers.IO + appJob)

    lateinit var uniMusicSync: UniMusicSync
        private set
    lateinit var uniMusicSyncPath: String


    override fun handleOnDestroy() {
        super.handleOnDestroy()

        appJob.cancelChildren()
        if (::uniMusicSync.isInitialized) {
            runBlocking {
                uniMusicSync.shutdown()
            }
            uniMusicSync.close()
        }
    }

    override fun load() {
        super.load()
        appScope.launch {
            val documentsPath = context.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)!!
            uniMusicSyncPath = documentsPath.resolve("UniMusicSync").path
            uniMusicSync = UniMusicSync.create(uniMusicSyncPath);
        }
    }

    private inline fun handleCallExceptions(call: PluginCall, block: () -> Unit) {
        try {
            block()
        } catch (e: Exception) {
            call.reject(e.message)
        }
    }

    @PluginMethod
    fun createNamespace(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                val namespace = uniMusicSync.createNamespace()
                val result = JSObject()
                result.put("namespace", namespace)
                call.resolve(result)
            }
        }
    }

    @PluginMethod
    fun deleteNamespace(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val namespace = call.getString("namespace") ?: run {
            call.reject("You must provide a 'namespace' option")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                uniMusicSync.deleteNamespace(namespace)
                call.resolve()
            }
        }
    }

    @PluginMethod
    fun getAuthor(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                val namespace = uniMusicSync.createNamespace()
                val result = JSObject()
                result.put("namespace", namespace)
                call.resolve(result)
            }
        }
    }

    @PluginMethod
    fun getNodeId(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                val nodeId = uniMusicSync.getNodeId()
                val result = JSObject()
                result.put("nodeId", nodeId)
                call.resolve(result)
            }
        }
    }

    @PluginMethod
    fun getFiles(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val namespace = call.getString("namespace") ?: run {
            call.reject("You must provide a 'namespace' option")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                val files = uniMusicSync.getFiles(namespace)
                val result = JSObject()

                for (entry in files) {
                    if (entry.isEmpty()) {
                        continue
                    }

                    val fileObject = JSObject()
                    fileObject.put("key", entry.key())
                    fileObject.put("author", entry.author())
                    fileObject.put("timestamp", entry.timestamp())
                    fileObject.put("contentHash", entry.contentHash())
                    fileObject.put("contentLen", entry.contentLen())

                    result.put(entry.key(), fileObject)
                }

                call.resolve(result)
            }
        }
    }


    @PluginMethod
    fun writeFile(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val namespace = call.getString("namespace") ?: run {
            call.reject("You must provide a 'namespace' option")
            return
        }

        val syncPath = call.getString("syncPath") ?: run {
            call.reject("You must provide a 'syncPath' option")
            return
        }

        // sourcePath in case of Android is a DocumentFile Uri
        val sourcePath = call.getString("sourcePath") ?: run {
            call.reject("You must provide a 'sourcePath' option")
            return
        }

        val fileUri = try {
            Uri.parse(sourcePath)
        } catch (e: Exception) {
            System.err.println(e)
            call.reject("'sourcePath' option has to be a valid SAF file uri")
            return
        }

        val file = DocumentFile.fromSingleUri(context, fileUri) ?: run {
            call.reject("Provided 'sourcePath' does not seem to exist")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                val inputStream = context.contentResolver.openInputStream(file.uri) ?: run {
                    call.reject("Failed to open input stream for ${file.uri}")
                    return@launch
                }
                val data = inputStream.use { inputStream.readBytes() }
                val fileHash = uniMusicSync.writeFile(namespace, syncPath, data)
                val result = JSObject()
                result.put("fileHash", fileHash)
                call.resolve(result)
            }
        }
    }

    @PluginMethod
    fun deleteFile(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val namespace = call.getString("namespace") ?: run {
            call.reject("You must provide a 'namespace' option")
            return
        }

        val syncPath = call.getString("syncPath") ?: run {
            call.reject("You must provide a 'syncPath' option")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                uniMusicSync.deleteFile(namespace, syncPath)
                call.resolve()
            }
        }
    }

    @PluginMethod
    fun readFile(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val namespace = call.getString("namespace") ?: run {
            call.reject("You must provide a 'namespace' option")
            return
        }

        val syncPath = call.getString("syncPath") ?: run {
            call.reject("You must provide a 'syncPath' option")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                val data = uniMusicSync.readFile(namespace, syncPath)
                val result = JSObject()
                // TODO: Serve the file
                result.put("url", "")
                call.resolve(result)
            }
        }
    }

    @PluginMethod
    fun readFileHash(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val fileHash = call.getString("fileHash") ?: run {
            call.reject("You must provide a 'fileHash' option")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                val data = uniMusicSync.readFileHash(fileHash)
                val result = JSObject()
                // TODO: Serve the file
                result.put("url", "")
                call.resolve(result)
            }
        }
    }

    @PluginMethod
    fun export(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val namespace = call.getString("namespace") ?: run {
            call.reject("You must provide a 'namespace' option")
            return
        }

        val syncPath = call.getString("syncPath") ?: run {
            call.reject("You must provide a 'syncPath' option")
            return
        }

        // destinationPath in case of Android is a DocumentFile Uri
        val destinationPath = call.getString("destinationPath") ?: run {
            call.reject("You must provide a 'destinationPath' option")
            return
        }

        val fileUri = try {
            Uri.parse(destinationPath)
        } catch (e: Exception) {
            System.err.println(e)
            call.reject("'destinationPath' option has to be a valid SAF file uri")
            return
        }

        val file = DocumentFile.fromSingleUri(context, fileUri) ?: run {
            call.reject("Provided 'destinationPath' does not seem to exist")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                // Since Android<->Rust filesystem interop would be a pain in the ass,
                // we do similar things to what Rust does directly here
                val outputStream = context.contentResolver.openOutputStream(file.uri) ?: run {
                    call.reject("Failed to open input stream for ${file.uri}")
                    return@launch
                }
                val data = uniMusicSync.readFile(namespace, syncPath)
                outputStream.use { outputStream.write(data) }
                call.resolve()
            }
        }
    }

    @PluginMethod
    fun exportHash(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val fileHash = call.getString("fileHash") ?: run {
            call.reject("You must provide a 'fileHash' option")
            return
        }

        // destinationPath in case of Android is a DocumentFile Uri
        val destinationPath = call.getString("destinationPath") ?: run {
            call.reject("You must provide a 'destinationPath' option")
            return
        }

        val fileUri = try {
            Uri.parse(destinationPath)
        } catch (e: Exception) {
            System.err.println(e)
            call.reject("'destinationPath' option has to be a valid SAF file uri")
            return
        }

        val file = DocumentFile.fromSingleUri(context, fileUri) ?: run {
            call.reject("Provided 'destinationPath' does not seem to exist")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                // Since Android<->Rust filesystem interop would be a pain in the ass,
                // we do similar things to what Rust does directly here
                val outputStream = context.contentResolver.openOutputStream(file.uri) ?: run {
                    call.reject("Failed to open input stream for ${file.uri}")
                    return@launch
                }
                val data = uniMusicSync.readFileHash(fileHash)
                outputStream.use { outputStream.write(data) }
                call.resolve()
            }
        }
    }

    @PluginMethod
    fun share(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val namespace = call.getString("namespace") ?: run {
            call.reject("You must provide a 'namespace' option")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                val ticket = uniMusicSync.share(namespace)
                val result = JSObject()
                result.put("ticket", ticket)
                call.resolve(result)
            }
        }
    }

    @PluginMethod
    fun import(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val ticket = call.getString("ticket") ?: run {
            call.reject("You must provide a 'ticket' option")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                val namespace = try {
                    uniMusicSync.import(ticket)
                } catch (e: Exception) {
                    System.err.println(e)
                    call.reject("Failed to import ticket")
                    return@launch
                }

                val result = JSObject()
                result.put("namespace", namespace)
                call.resolve(result)
            }
        }
    }

    @PluginMethod
    fun sync(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        val namespace = call.getString("namespace") ?: run {
            call.reject("You must provide a 'namespace' option")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                try {
                    uniMusicSync.sync(namespace)
                } catch (e: Exception) {
                    System.err.println(e)
                }
                call.resolve()
            }
        }
    }

    @PluginMethod
    fun reconnect(call: PluginCall) {
        if (!::uniMusicSync.isInitialized) {
            call.reject("UniMusicSync is not initialized")
            return
        }

        appScope.launch {
            handleCallExceptions(call) {
                uniMusicSync.reconnect()
                call.resolve()
            }
        }
    }
}