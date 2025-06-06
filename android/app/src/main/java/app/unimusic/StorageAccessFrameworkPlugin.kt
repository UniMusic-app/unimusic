package app.unimusic

import android.Manifest
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import com.getcapacitor.annotation.Permission
import java.util.regex.Pattern

@Suppress("unused")
@CapacitorPlugin(
    name = "StorageAccessFramework",
    permissions = [
        Permission(
            alias = "readExternalStorage",
            strings = [Manifest.permission.READ_EXTERNAL_STORAGE]
        ),
        Permission(
            alias = "writeExternalStorage",
            strings = [Manifest.permission.WRITE_EXTERNAL_STORAGE]
        )
    ]
)
class StorageAccessFrameworkPlugin : Plugin() {
    private fun resolveDocumentFile(rootFile: DocumentFile, path: String): DocumentFile? {
        var current: DocumentFile? = rootFile
        println("Start: $current")
        val segments = path.split(Pattern.compile("/+")).filter { segment -> !segment.isEmpty() }
        println("Segments: $segments")
        for (segment in segments) {
            if (current == null || !current.exists() || !current.isDirectory) {
                return null
            }

            current = current.findFile(segment)
        }
        println("End: $current")

        return current
    }

    /// Requires 'treeUri' option to be provided
    private fun getRootFileFromOptions(call: PluginCall): DocumentFile? {
        val treeUriString = call.getString("treeUri") ?: run {
            call.reject("You need to provide 'treeUri' option")
            return null
        }
        val treeUri = try {
            Uri.parse(treeUriString)
        } catch (e: Exception) {
            System.err.println(e)
            call.reject("You need to provide valid 'treeUri' uri")
            return null
        }

        val hasPermission = context.contentResolver.persistedUriPermissions.any { permission ->
            permission.uri == treeUri && permission.isReadPermission
        }

        if (!hasPermission) {
            call.reject("You do not have proper permissions to access files under provided 'treeUri'")
            return null
        }

        val rootFile = DocumentFile.fromTreeUri(context, treeUri) ?: run {
            call.reject("Provided 'treeUri' does not seem to exist")
            return null
        }

        return rootFile
    }

    /// Requires 'path' and 'treeUri' options to be provided
    private fun getFileFromOptions(call: PluginCall): DocumentFile? {
        val path = call.getString("path") ?: run {
            call.reject("You need to provide 'path' option")
            return null
        }

        val rootFile = getRootFileFromOptions(call) ?: return null

        if (!rootFile.exists() || !rootFile.isDirectory) {
            call.reject("Provided 'treeUri' is either not a directory, or it does not exist")
            return null
        }

        val file = resolveDocumentFile(rootFile, path) ?: run {
            call.reject("Provided 'path' does not seem to exist within 'treeUri'")
            return null
        }

        return file
    }

    private fun parseFileInfo(file: DocumentFile): JSObject {
        val result = JSObject()
        result.put("name", file.name)
        result.put("type", if (file.isDirectory) "directory" else "file")
        result.put("size", file.length())
        result.put("mtime", file.lastModified())
        result.put("uri", file.uri.toString())
        return result
    }

    @PluginMethod
    fun ensureFile(call: PluginCall) {
        val path = call.getString("path") ?: run {
            call.reject("You need to provide 'path' option")
            return
        }

        val rootFile = getRootFileFromOptions(call) ?: return

        val file = run {
            var currentFile = rootFile

            val segments = ArrayDeque(
                path.split(Pattern.compile("/+"))
                    .filter { segment -> !segment.isEmpty() }
            )
            val fileSegment = segments.removeLast()

            for (segment in segments) {
                val next = currentFile.findFile(segment) ?: currentFile.createDirectory(segment)!!
                if (!next.isDirectory) {
                    throw Exception("Expected directory on $segment when creating $path in ${rootFile.uri}")
                }
                currentFile = next
            }


            currentFile.findFile(fileSegment) ?: currentFile.createFile("*/*", fileSegment)!!
        }

        val result = JSObject()
        result.put("uri", file.uri.toString())
        call.resolve(result)
    }

    @PluginMethod
    fun stat(call: PluginCall) {
        val file = getFileFromOptions(call) ?: return
        val fileInfo = parseFileInfo(file)
        call.resolve(fileInfo)
    }

    @PluginMethod
    fun readdir(call: PluginCall) {
        val dir = getFileFromOptions(call) ?: return

        if (!dir.isDirectory) {
            call.reject("Provided 'path' is not a directory")
            return
        }

        val files = JSArray()
        for (entry in dir.listFiles()) {
            files.put(parseFileInfo(entry))
        }

        val result = JSObject()
        result.put("files", files)
        call.resolve(result)
    }


}