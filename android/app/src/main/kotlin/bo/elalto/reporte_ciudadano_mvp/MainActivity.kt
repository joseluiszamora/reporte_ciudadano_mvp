package bo.elalto.reporte_ciudadano_mvp

import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bo.elalto.reports/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText") {
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
                    startActivity(Intent.createChooser(intent, null))
                    result.success(null)
                } catch (_: ActivityNotFoundException) {
                    result.error("SHARE_UNAVAILABLE", "No se pudo abrir la hoja de compartir.", null)
                }
            }
    }
}
