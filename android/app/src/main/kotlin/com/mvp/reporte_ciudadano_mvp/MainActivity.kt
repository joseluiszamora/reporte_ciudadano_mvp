package com.mvp.reporte_ciudadano_mvp

import android.content.ClipData
import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File
import java.io.IOException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bo.elalto.reports/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText" && call.method != "sharePhoto") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val text = call.argument<String>("text")
                if (text.isNullOrBlank()) {
                    result.error("EMPTY_SUMMARY", "El resumen está vacío.", null)
                    return@setMethodCallHandler
                }
                val intent = Intent(Intent.ACTION_SEND)
                    .setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, text)
                try {
                    if (call.method == "sharePhoto") {
                        val photo = call.argument<ByteArray>("photo")
                        val mime = call.argument<String>("mimeType")
                        val extension = when (mime) {
                            "image/jpeg" -> ".jpg"
                            "image/png" -> ".png"
                            "image/webp" -> ".webp"
                            else -> null
                        }
                        if (photo == null || photo.isEmpty() || extension == null) {
                            result.error("INVALID_PHOTO", "La fotografía no está disponible.", null)
                            return@setMethodCallHandler
                        }
                        val folder = File(cacheDir, "shared-report-photos")
                        folder.mkdirs()
                        val cutoff = System.currentTimeMillis() - 24 * 60 * 60 * 1000L
                        folder.listFiles()?.filter { it.lastModified() < cutoff }?.forEach { it.delete() }
                        val file = File.createTempFile("reporte-", extension, folder)
                        file.writeBytes(photo)
                        val uri = FileProvider.getUriForFile(this, "$packageName.reportphotos", file)
                        intent.setType(mime)
                            .putExtra(Intent.EXTRA_STREAM, uri)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        intent.clipData = ClipData.newUri(contentResolver, "Fotografía", uri)
                    }
                    startActivity(Intent.createChooser(intent, null))
                    result.success(null)
                } catch (_: IOException) {
                    result.error("SHARE_UNAVAILABLE", "No se pudo preparar la fotografía.", null)
                } catch (_: ActivityNotFoundException) {
                    result.error("SHARE_UNAVAILABLE", "No se pudo abrir la hoja de compartir.", null)
                }
            }
    }
}
