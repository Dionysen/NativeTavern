package com.miaomiaoxworld.nativetavern.qnn_upscale

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Android Snapdragon QNN anime upscale bridge.
 *
 * Requires Local Dream-compatible `libstable_diffusion_core.so` in jniLibs and
 * QNN runtime libs under assets/qnnlibs. Without them, [getCapability] reports
 * unavailable and the Dart stage skips upscale.
 */
class NativeTavernQnnUpscalePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var appContext: Context? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val backendProcess = AtomicReference<Process?>(null)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stopBackend()
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getCapability" -> {
                val ctx = appContext
                if (ctx == null) {
                    result.success(capabilityMap(available = false, reason = "No context"))
                    return
                }
                result.success(buildCapability(ctx))
            }

            "ensureModel" -> {
                val ctx = appContext
                if (ctx == null) {
                    result.error("no_context", "Plugin context missing", null)
                    return
                }
                executor.execute {
                    try {
                        ensureModelFile(ctx)
                        runOnMain { result.success(null) }
                    } catch (error: Exception) {
                        Log.e(TAG, "ensureModel failed", error)
                        runOnMain {
                            result.error("ensure_failed", error.message, null)
                        }
                    }
                }
            }

            "upscale" -> {
                val ctx = appContext
                if (ctx == null) {
                    result.error("no_context", "Plugin context missing", null)
                    return
                }
                val bytes = call.argument<ByteArray>("bytes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val targetScale = (call.argument<Int>("targetScale") ?: NATIVE_SCALE)
                    .coerceIn(1, NATIVE_SCALE)
                if (bytes == null || bytes.isEmpty() || width <= 0 || height <= 0) {
                    result.error("bad_args", "bytes/width/height required", null)
                    return
                }
                executor.execute {
                    try {
                        val jpeg = upscaleImage(ctx, bytes, width, height, targetScale)
                        runOnMain { result.success(jpeg) }
                    } catch (error: Exception) {
                        Log.e(TAG, "upscale failed", error)
                        runOnMain {
                            result.error("upscale_failed", error.message, null)
                        }
                    }
                }
            }

            "dispose" -> {
                executor.execute {
                    stopBackend()
                    runOnMain { result.success(null) }
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun buildCapability(context: Context): Map<String, Any?> {
        val soc = deviceSoc()
        val qualcomm = isQualcommSoc(soc)
        val suffix = chipsetSuffix(soc)
        val hasRuntime = nativeExecutable(context)?.exists() == true
        val modelReady = modelFile(context).let { it.exists() && it.length() > 0L }
        val available = qualcomm && hasRuntime
        val reason = when {
            !qualcomm -> "Not a Qualcomm Snapdragon device ($soc)."
            !hasRuntime ->
                "Missing libstable_diffusion_core.so. Place it under jniLibs/arm64-v8a."
            else -> null
        }
        return capabilityMap(
            available = available,
            soc = soc,
            modelSuffix = suffix,
            hasNativeRuntime = hasRuntime,
            modelReady = modelReady,
            reason = reason,
        )
    }

    private fun capabilityMap(
        available: Boolean,
        soc: String? = null,
        modelSuffix: String? = null,
        hasNativeRuntime: Boolean = false,
        modelReady: Boolean = false,
        reason: String? = null,
    ): Map<String, Any?> = mapOf(
        "available" to available,
        "soc" to soc,
        "modelSuffix" to modelSuffix,
        "hasNativeRuntime" to hasNativeRuntime,
        "modelReady" to modelReady,
        "reason" to reason,
    )

    private fun ensureModelFile(context: Context) {
        val file = modelFile(context)
        if (file.exists() && file.length() > 0L) return
        file.parentFile?.mkdirs()
        val soc = deviceSoc()
        val suffix = chipsetSuffix(soc) ?: "min"
        val url =
            "https://huggingface.co/xororz/upscaler/resolve/main/" +
                "realesrgan_x4plus_anime_6b/upscaler_$suffix.bin"
        Log.i(TAG, "Downloading anime upscaler: $url")
        downloadToFile(url, file)
        if (!file.exists() || file.length() == 0L) {
            throw IllegalStateException("Upscaler download produced an empty file")
        }
    }

    private fun upscaleImage(
        context: Context,
        encoded: ByteArray,
        width: Int,
        height: Int,
        targetScale: Int,
    ): ByteArray {
        ensureModelFile(context)
        prepareRuntimeLibs(context)
        ensureBackendRunning(context)

        val bitmap = BitmapFactory.decodeByteArray(encoded, 0, encoded.size)
            ?: throw IllegalStateException("Failed to decode image bytes")
        val w = if (width > 0) width else bitmap.width
        val h = if (height > 0) height else bitmap.height
        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)
        bitmap.recycle()

        val rgb = ByteArray(w * h * 3)
        for (i in pixels.indices) {
            val pixel = pixels[i]
            rgb[i * 3] = ((pixel shr 16) and 0xFF).toByte()
            rgb[i * 3 + 1] = ((pixel shr 8) and 0xFF).toByte()
            rgb[i * 3 + 2] = (pixel and 0xFF).toByte()
        }

        val upscalerPath = modelFile(context).absolutePath
        val jpeg = postUpscale(rgb, w, h, upscalerPath)

        if (targetScale == NATIVE_SCALE) return jpeg

        val decoded = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)
            ?: return jpeg
        val targetW = w * targetScale
        val targetH = h * targetScale
        val scaled = Bitmap.createScaledBitmap(decoded, targetW, targetH, true)
        if (scaled !== decoded) decoded.recycle()
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 92, out)
        scaled.recycle()
        return out.toByteArray()
    }

    private fun postUpscale(
        rgb: ByteArray,
        width: Int,
        height: Int,
        upscalerPath: String,
    ): ByteArray {
        val url = URL("http://127.0.0.1:$PORT/upscale")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 15_000
            readTimeout = 180_000
            setRequestProperty("Content-Type", "application/octet-stream")
            setRequestProperty("X-Image-Width", width.toString())
            setRequestProperty("X-Image-Height", height.toString())
            setRequestProperty("X-Upscaler-Path", upscalerPath)
        }
        try {
            conn.outputStream.use { it.write(rgb) }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val body = stream?.use { it.readBytes() } ?: ByteArray(0)
            if (code !in 200..299) {
                throw IllegalStateException(
                    "Upscale HTTP $code: ${body.toString(Charsets.UTF_8).take(300)}",
                )
            }
            if (body.isEmpty()) throw IllegalStateException("Empty upscale response")
            return body
        } finally {
            conn.disconnect()
        }
    }

    private fun ensureBackendRunning(context: Context) {
        val alive = backendProcess.get()?.isAlive == true
        if (alive && waitForHealth(timeoutMs = 2_000)) return
        stopBackend()
        startBackend(context)
        if (!waitForHealth(timeoutMs = 30_000)) {
            throw IllegalStateException("Upscaler backend failed to become healthy")
        }
    }

    private fun startBackend(context: Context) {
        val executable = nativeExecutable(context)
            ?: throw IllegalStateException("Native upscaler executable not found")
        val runtimeDir = prepareRuntimeLibs(context)
        val command = listOf(
            executable.absolutePath,
            "--upscaler_mode",
            "--lib_dir",
            runtimeDir.absolutePath,
            "--port",
            PORT.toString(),
        )
        val envPath = listOf(
            runtimeDir.absolutePath,
            "/system/lib64",
            "/vendor/lib64",
            "/vendor/lib64/egl",
        ).joinToString(":")
        Log.i(TAG, "Starting upscaler: ${command.joinToString(" ")}")
        val builder = ProcessBuilder(command).apply {
            directory(executable.parentFile)
            redirectErrorStream(true)
            environment()["LD_LIBRARY_PATH"] = envPath
            environment()["DSP_LIBRARY_PATH"] = runtimeDir.absolutePath
        }
        val process = builder.start()
        backendProcess.set(process)
        Thread({
            try {
                process.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach { Log.i(TAG, "backend: $it") }
                }
            } catch (_: Exception) {
            }
        }, "qnn-upscale-log").apply { isDaemon = true }.start()
    }

    private fun stopBackend() {
        val process = backendProcess.getAndSet(null) ?: return
        try {
            process.destroy()
            if (!process.waitFor(5, TimeUnit.SECONDS)) {
                process.destroyForcibly()
            }
        } catch (error: Exception) {
            Log.w(TAG, "Failed to stop upscaler backend", error)
        }
    }

    private fun waitForHealth(timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            if (backendProcess.get()?.isAlive != true) return false
            try {
                val url = URL("http://127.0.0.1:$PORT/health")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    connectTimeout = 500
                    readTimeout = 500
                    requestMethod = "GET"
                }
                conn.inputStream.use { }
                val ok = conn.responseCode in 200..299
                conn.disconnect()
                if (ok) return true
            } catch (_: Exception) {
                // retry
            }
            Thread.sleep(250)
        }
        return false
    }

    private fun prepareRuntimeLibs(context: Context): File {
        val runtimeDir = File(context.filesDir, RUNTIME_DIR)
        if (!runtimeDir.exists()) runtimeDir.mkdirs()
        try {
            val assets = context.assets.list("qnnlibs") ?: emptyArray()
            for (name in assets) {
                if (name.isBlank() || name == "README.md") continue
                val target = File(runtimeDir, name)
                if (target.exists() && target.length() > 0L) continue
                context.assets.open("qnnlibs/$name").use { input ->
                    FileOutputStream(target).use { output -> input.copyTo(output) }
                }
                target.setReadable(true, true)
                target.setExecutable(true, true)
            }
        } catch (error: Exception) {
            Log.w(TAG, "prepareRuntimeLibs: ${error.message}")
        }
        runtimeDir.setReadable(true, true)
        runtimeDir.setExecutable(true, true)
        return runtimeDir
    }

    private fun nativeExecutable(context: Context): File? {
        val nativeDir = context.applicationInfo.nativeLibraryDir ?: return null
        val file = File(nativeDir, EXECUTABLE_NAME)
        return if (file.exists()) file else null
    }

    private fun modelFile(context: Context): File {
        return File(File(context.filesDir, "upscalers/upscaler_anime"), MODEL_FILE)
    }

    private fun downloadToFile(url: String, target: File) {
        val tmp = File(target.absolutePath + ".part")
        if (tmp.exists()) tmp.delete()
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 30_000
            readTimeout = 120_000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", "NativeTavern-QnnUpscale/0.1")
        }
        try {
            if (conn.responseCode !in 200..299) {
                throw IllegalStateException("Download HTTP ${conn.responseCode}")
            }
            BufferedInputStream(conn.inputStream).use { input ->
                FileOutputStream(tmp).use { output -> input.copyTo(output) }
            }
            if (!tmp.renameTo(target)) {
                tmp.copyTo(target, overwrite = true)
                tmp.delete()
            }
        } finally {
            conn.disconnect()
        }
    }

    private fun runOnMain(block: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(block)
    }

    companion object {
        private const val TAG = "NtQnnUpscale"
        private const val CHANNEL = "native_tavern_qnn_upscale"
        private const val EXECUTABLE_NAME = "libstable_diffusion_core.so"
        private const val MODEL_FILE = "upscaler.bin"
        private const val RUNTIME_DIR = "qnn_upscale_runtime"
        private const val PORT = 18081
        private const val NATIVE_SCALE = 4

        private val chipsetSuffixes = mapOf(
            "SM8475" to "8gen1",
            "SM8450" to "8gen1",
            "SM8550" to "8gen2",
            "SM8550P" to "8gen2",
            "QCS8550" to "8gen2",
            "QCM8550" to "8gen2",
            "SM8650" to "8gen2",
            "SM8650P" to "8gen2",
            "SM8750" to "8gen2",
            "SM8750P" to "8gen2",
            "SM8850" to "8gen2",
            "SM8850P" to "8gen2",
            "SM8735" to "8gen2",
            "SM8845" to "8gen2",
            "SM8950" to "8gen2",
            "SM8975" to "8gen2",
        )

        private fun deviceSoc(): String {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                Build.SOC_MODEL.ifBlank { "UNKNOWN" }
            } else {
                "CPU"
            }
        }

        private fun isQualcommSoc(soc: String): Boolean {
            val upper = soc.uppercase()
            val prefixes = listOf(
                "SM", "QCS", "QCM", "CQ", "IPQ", "SXR", "AIC", "SSG",
                "SC", "SA", "SDM", "MSM", "QRB", "X1E", "X1P",
            )
            return prefixes.any { upper.startsWith(it) }
        }

        private fun chipsetSuffix(soc: String): String? {
            val upper = soc.uppercase()
            chipsetSuffixes[upper]?.let { return it }
            if (upper.startsWith("SM")) return "min"
            return null
        }
    }
}
