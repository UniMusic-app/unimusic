package app.unimusic

import android.content.Intent
import androidx.activity.result.ActivityResult
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.ActivityCallback
import com.getcapacitor.annotation.CapacitorPlugin

@CapacitorPlugin(name = "DirectoryPicker")
class DirectoryPickerPlugin : Plugin() {

    @PluginMethod
    fun pickDirectory(call: PluginCall) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }

        startActivityForResult(call, intent, "finishPickingDirectory")
    }

    @ActivityCallback
    fun finishPickingDirectory(call: PluginCall, resultIntent: ActivityResult?) {
        if (resultIntent == null) {
            call.reject("Picking directory failed")
            return
        }

        resultIntent.data?.data.also { treeUri ->
            if (treeUri == null) {
                call.reject("Picking directory failed: treeUri is null")
                return
            }

            val result = JSObject()
            result.put("path", treeUri.path)
            call.resolve(result)
        } ?: run {
            call.reject("Picking directory failed")
        }
    }
}