package com.miaomiaoxworld.nativetavern

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.telephony.TelephonyManager
import android.view.Surface
import android.view.SurfaceHolder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val REGION_CHANNEL = "com.nativetavern/region"
    private val MEDIA_CHANNEL = "com.nativetavern/media"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        // Some OEMs reset window preferred mode when returning to foreground.
        requestHighestRefreshRate()
    }

    override fun onFlutterSurfaceViewCreated(flutterSurfaceView: FlutterSurfaceView) {
        super.onFlutterSurfaceViewCreated(flutterSurfaceView)
        requestHighestRefreshRate()
        applySurfaceFrameRate(flutterSurfaceView.holder.surface)
        flutterSurfaceView.holder.addCallback(
            object : SurfaceHolder.Callback {
                override fun surfaceCreated(holder: SurfaceHolder) {
                    requestHighestRefreshRate()
                    applySurfaceFrameRate(holder.surface)
                }

                override fun surfaceChanged(
                    holder: SurfaceHolder,
                    format: Int,
                    width: Int,
                    height: Int,
                ) {
                    applySurfaceFrameRate(holder.surface)
                }

                override fun surfaceDestroyed(holder: SurfaceHolder) {}
            },
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REGION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isChinaRegion" -> result.success(isChinaRegion())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImageToDownloads" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val fileName = call.argument<String>("fileName")
                        if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error(
                                "INVALID_ARGS",
                                "sourcePath and fileName are required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(saveImageToDownloads(sourcePath, fileName))
                        } catch (error: Exception) {
                            result.error(
                                "SAVE_FAILED",
                                error.message ?: "Failed to save image",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Writes [sourcePath] into public `Download/NativeTavern/[fileName]`.
     * Uses MediaStore on Android 10+ so scoped storage still lands in Downloads.
     */
    private fun saveImageToDownloads(sourcePath: String, fileName: String): String {
        val source = File(sourcePath)
        if (!source.exists() || !source.isFile) {
            throw IllegalArgumentException("Source image not found")
        }
        val mime = mimeTypeForFileName(fileName)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/NativeTavern",
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Unable to create Downloads entry")
            try {
                resolver.openOutputStream(uri)?.use { output ->
                    source.inputStream().use { input -> input.copyTo(output) }
                } ?: throw IllegalStateException("Unable to open Downloads stream")
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return uri.toString()
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }
        }

        @Suppress("DEPRECATION")
        val downloadsRoot = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        val folder = File(downloadsRoot, "NativeTavern")
        if (!folder.exists() && !folder.mkdirs()) {
            throw IllegalStateException("Unable to create Download/NativeTavern")
        }
        val dest = File(folder, fileName)
        source.copyTo(dest, overwrite = true)
        MediaScannerConnection.scanFile(
            this,
            arrayOf(dest.absolutePath),
            arrayOf(mime),
            null,
        )
        return dest.absolutePath
    }

    private fun mimeTypeForFileName(fileName: String): String {
        val lower = fileName.lowercase(Locale.ROOT)
        return when {
            lower.endsWith(".jpg") || lower.endsWith(".jpeg") -> "image/jpeg"
            lower.endsWith(".webp") -> "image/webp"
            lower.endsWith(".gif") -> "image/gif"
            else -> "image/png"
        }
    }

    /** Ask Android for the highest refresh rate matching the current resolution. */
    private fun requestHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        } ?: return

        val current = display.mode
        val best = display.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate }
            ?: display.supportedModes.maxByOrNull { it.refreshRate }
            ?: return

        val attrs = window.attributes
        attrs.preferredDisplayModeId = best.modeId
        // Explicit numeric hint; helps LTPO / "follow app" OEM policies.
        attrs.preferredRefreshRate = best.refreshRate
        window.attributes = attrs
    }

    /** Vote for a fixed high frame rate on Flutter's rendering surface. */
    private fun applySurfaceFrameRate(surface: Surface?) {
        if (surface == null || !surface.isValid) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return

        val targetHz = display
            ?.supportedModes
            ?.maxOfOrNull { it.refreshRate }
            ?: 120f

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                surface.setFrameRate(
                    targetHz,
                    Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                    Surface.CHANGE_FRAME_RATE_ALWAYS,
                )
            } else {
                surface.setFrameRate(
                    targetHz,
                    Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                )
            }
        } catch (_: Throwable) {
            // OEM / API quirks should never crash startup.
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
