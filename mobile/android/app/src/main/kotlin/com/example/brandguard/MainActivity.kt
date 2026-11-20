package com.example.brandguard

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "brandguard/files"
        ).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                val rawName = call.argument<String>("name") ?: "brandguard_file"
                val safeName = rawName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("INVALID_ARGS", "Missing file bytes", null)
                    return@setMethodCallHandler
                }
                try {
                    val savedPath = saveFileToDownloads(safeName, mimeType, bytes)
                    result.success(savedPath)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message ?: "Unable to save file", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveFileToDownloads(fileName: String, mimeType: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/BrandGuard"
                )
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create Downloads entry")
            try {
                resolver.openOutputStream(uri)?.use { stream ->
                    stream.write(bytes)
                } ?: throw IllegalStateException("Could not open Downloads output stream")
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return "Downloads/BrandGuard/$fileName"
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
        }
        val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
        val outDir = File(dir, "BrandGuard").apply { mkdirs() }
        val outFile = File(outDir, fileName)
        outFile.writeBytes(bytes)
        return outFile.absolutePath
    }
}
