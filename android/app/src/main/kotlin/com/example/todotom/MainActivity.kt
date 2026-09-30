package com.example.todotom

import android.app.Activity
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pickSoundResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickSound" -> {
                        pickSoundResult = result
                        val existingUri = call.argument<String>("existingUri")
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(
                                RingtoneManager.EXTRA_RINGTONE_TYPE,
                                RingtoneManager.TYPE_NOTIFICATION or
                                    RingtoneManager.TYPE_RINGTONE or
                                    RingtoneManager.TYPE_ALARM,
                            )
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Elegir tono de aviso")
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            putExtra(
                                RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                                if (!existingUri.isNullOrEmpty()) {
                                    Uri.parse(existingUri)
                                } else {
                                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                                },
                            )
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, PICK_SOUND_REQUEST)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == PICK_SOUND_REQUEST) {
            val pending = pickSoundResult
            pickSoundResult = null
            if (pending == null) return

            if (resultCode != Activity.RESULT_OK) {
                pending.success(null)
                return
            }

            val uri = readPickedUri(data)
            if (uri == null) {
                pending.success(null)
                return
            }

            val ringtone = RingtoneManager.getRingtone(this, uri)
            val title = ringtone?.getTitle(this)?.takeIf { it.isNotBlank() }
                ?: "Tono del teléfono"
            pending.success(
                mapOf(
                    "uri" to uri.toString(),
                    "title" to title,
                ),
            )
            return
        }

        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun readPickedUri(data: Intent?): Uri? {
        if (data == null) return null

        val picked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        }
        if (picked != null) return picked

        // Algunos fabricantes (p. ej. Samsung) devuelven la URI en otra clave.
        @Suppress("DEPRECATION")
        return data.getParcelableExtra("android.intent.extra.ringtone")
    }

    companion object {
        private const val CHANNEL_NAME = "com.example.todotom/reminder_sound"
        private const val PICK_SOUND_REQUEST = 9101
    }
}
