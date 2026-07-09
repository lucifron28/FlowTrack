package com.flowtrack.app

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val barcodeChannelName = "flowtrack/barcode_pdf"
    private val backupChannelName = "flowtrack/backup_file"
    private val pickBackupRequestCode = 4101
    private var pendingPickBackupResult: Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, barcodeChannelName).setMethodCallHandler { call, result ->
            val fileName = call.argument<String>("fileName")
            val bytes = call.argument<ByteArray>("bytes")
            if (fileName.isNullOrBlank() || bytes == null) {
                result.error("barcode_pdf_args", "Missing PDF file name or bytes.", null)
                return@setMethodCallHandler
            }

            try {
                when (call.method) {
                    "savePdf" -> result.success(savePdf(fileName, bytes).toString())
                    "sharePdf" -> {
                        val uri = savePdf(fileName, bytes)
                        sharePdf(uri)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("barcode_pdf_failed", error.message, null)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "saveBackup" -> {
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (fileName.isNullOrBlank() || bytes == null) {
                            result.error("backup_args", "Missing backup file name or bytes.", null)
                            return@setMethodCallHandler
                        }
                        result.success(saveBackup(fileName, bytes).toString())
                    }
                    "shareBackup" -> {
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (fileName.isNullOrBlank() || bytes == null) {
                            result.error("backup_args", "Missing backup file name or bytes.", null)
                            return@setMethodCallHandler
                        }
                        val uri = saveBackup(fileName, bytes)
                        shareBackup(uri)
                        result.success(null)
                    }
                    "pickBackup" -> pickBackup(result)
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("backup_failed", error.message, null)
            }
        }
    }

    @Deprecated("Deprecated in Android framework, still supported by FlutterActivity.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickBackupRequestCode) {
            return
        }
        val pending = pendingPickBackupResult ?: return
        pendingPickBackupResult = null
        if (resultCode != Activity.RESULT_OK) {
            pending.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            pending.success(null)
            return
        }
        try {
            val bytes = applicationContext.contentResolver.openInputStream(uri)?.use { input ->
                input.readBytes()
            } ?: throw IllegalStateException("Could not read backup file.")
            pending.success(bytes)
        } catch (error: Exception) {
            pending.error("backup_pick_failed", error.message, null)
        }
    }

    private fun savePdf(fileName: String, bytes: ByteArray): Uri {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create PDF file.")
            resolver.openOutputStream(uri)?.use { output -> output.write(bytes) }
                ?: throw IllegalStateException("Could not write PDF file.")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            uri
        } else {
            val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                ?: throw IllegalStateException("Downloads directory is unavailable.")
            if (!directory.exists()) {
                directory.mkdirs()
            }
            val file = File(directory, fileName)
            FileOutputStream(file).use { output -> output.write(bytes) }
            Uri.fromFile(file)
        }
    }

    private fun sharePdf(uri: Uri) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IllegalStateException("Sharing barcode PDFs requires Android 10 or newer. Use Save PDF instead.")
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Share barcode PDF"))
    }

    private fun saveBackup(fileName: String, bytes: ByteArray): Uri {
        val mimeType = "application/json"
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create backup file.")
            resolver.openOutputStream(uri)?.use { output -> output.write(bytes) }
                ?: throw IllegalStateException("Could not write backup file.")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            uri
        } else {
            val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                ?: throw IllegalStateException("Downloads directory is unavailable.")
            if (!directory.exists()) {
                directory.mkdirs()
            }
            val file = File(directory, fileName)
            FileOutputStream(file).use { output -> output.write(bytes) }
            Uri.fromFile(file)
        }
    }

    private fun shareBackup(uri: Uri) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IllegalStateException("Sharing backup files requires Android 10 or newer. Use Save backup instead.")
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/json"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Share FlowTrack backup"))
    }

    private fun pickBackup(result: Result) {
        if (pendingPickBackupResult != null) {
            result.error("backup_pick_active", "A backup picker is already open.", null)
            return
        }
        pendingPickBackupResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/json", "application/octet-stream", "text/plain")
            )
        }
        startActivityForResult(Intent.createChooser(intent, "Choose FlowTrack backup"), pickBackupRequestCode)
    }
}
