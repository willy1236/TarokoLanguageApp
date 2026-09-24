package tw.idv.willy1236.truku

import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // targetSdk 35 起系統強制無邊框；舊版 Android 也明確開啟，讓各版本行為一致，插邊交給 Flutter 的 SafeArea / MediaQuery.padding。
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 好友來電響鈴要依鈴聲模式決定響鈴／震動；vibration 套件不看鈴聲模式，只能自己查。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "truku/ringer_mode")
            .setMethodCallHandler { call, result ->
                if (call.method != "getRingerMode") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                result.success(
                    when (audioManager.ringerMode) {
                        AudioManager.RINGER_MODE_SILENT -> "silent"
                        AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
                        else -> "normal"
                    }
                )
            }
    }
}
