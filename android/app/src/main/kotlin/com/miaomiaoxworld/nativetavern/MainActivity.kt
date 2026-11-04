package com.miaomiaoxworld.nativetavern

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nativetavern/region"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isChinaRegion" -> {
                    result.success(isChinaRegion())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isChinaRegion(): Boolean {
        // Check SIM country code
        try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            val simCountry = telephonyManager?.simCountryIso?.uppercase(Locale.ROOT)
            if (simCountry == "CN") {
                return true
            }

            // Check network country code
            val networkCountry = telephonyManager?.networkCountryIso?.uppercase(Locale.ROOT)
            if (networkCountry == "CN") {
                return true
            }
        } catch (e: Exception) {
            // Ignore errors
        }

        // Check system locale
        val locale = Locale.getDefault()
        if (locale.country == "CN" && locale.language == "zh") {
            return true
        }

        return false
    }
}
