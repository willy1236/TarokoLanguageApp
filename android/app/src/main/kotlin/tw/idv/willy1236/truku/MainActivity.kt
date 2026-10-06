package tw.idv.willy1236.truku

import android.content.Context
import android.content.res.Configuration
import android.media.AudioManager
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    // App 只有繁中介面：原生元件（Google 地圖的地名與標籤等）也固定用繁中，不跟手機系統語言。
    override fun attachBaseContext(newBase: Context) {
        Locale.setDefault(APP_LOCALE)
        val config = Configuration(newBase.resources.configuration)
        config.setLocale(APP_LOCALE)
        super.attachBaseContext(newBase.createConfigurationContext(config))
    }

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

    private companion object {
        val APP_LOCALE: Locale = Locale.TRADITIONAL_CHINESE
    }
}
