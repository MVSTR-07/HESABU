package ke.co.hesabu.hesabu

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import java.io.ByteArrayOutputStream

/** Streams a LOCAL document to Dart memory; never creates a plaintext cache. */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private val requestCode = 7402
    private val maxBytes = 25 * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hesabu/local_statement_picker")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") { result.notImplemented() }
                else if (pending != null) { result.error("busy", "A file dialog is already open.", null) }
                else {
                    pending = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_LOCAL_ONLY, true)
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf", "text/csv", "text/comma-separated-values"))
                        }
                        startActivityForResult(intent, requestCode)
                    } catch (_: Exception) {
                        pending = null
                        result.error("picker_failed", "The local file picker could not open.", null)
                    }
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != this.requestCode) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        Thread {
            try {
                var name = "statement"
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                    if (it.moveToFirst()) name = it.getString(0) ?: name
                }
                val output = ByteArrayOutputStream()
                contentResolver.openInputStream(uri)?.use { input ->
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (output.size() + count > maxBytes) throw IllegalArgumentException("too_large")
                        output.write(buffer, 0, count)
                    }
                } ?: throw IllegalStateException("read_failed")
                val bytes = output.toByteArray()
                runOnUiThread { result.success(mapOf("name" to name, "bytes" to bytes)) }
            } catch (error: Exception) {
                val message = if (error is IllegalArgumentException) "File exceeds 25 MB. Choose a shorter statement."
                    else "The local file could not be read. Choose a PDF or CSV from this device."
                // Never log filenames, URIs, document contents or passwords.
                runOnUiThread { result.error("read_failed", message, null) }
            }
        }.start()
    }
}
