package com.miaomiaoxworld.nativetavern.qnn_upscale

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Base64
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedReader
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import java.util.zip.ZipInputStream

/**
 * Android Snapdragon QNN bridge:
 * - anime upscale on port [UPSCALE_PORT]
 * - SD1.5 NPU generation on port [GEN_PORT] with explicit start/stop + status events
 */
class NativeTavernQnnUpscalePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var appContext: Context? = null
    private var eventSink: EventChannel.EventSink? = null

    private val executor = Executors.newSingleThreadExecutor()
    private val upscaleProcess = AtomicReference<Process?>(null)
    private val genProcess = AtomicReference<Process?>(null)
    private val cancelDownload = AtomicBoolean(false)
    private val cancelGenerate = AtomicBoolean(false)

    @Volatile private var statusState: String = STATE_IDLE
    @Volatile private var statusModelId: String? = null
    @Volatile private var statusModelName: String? = null
    @Volatile private var statusProgress: Double? = null
    @Volatile private var statusMessage: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        stopGenerationBackend(emit = false)
        stopUpscaleBackend()
        appContext = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        emitStatus()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getCapability" -> {
                val ctx = appContext
                if (ctx == null) {
                    result.success(capabilityMap(available = false, generationAvailable = false, reason = "No context"))
                    return
                }
                result.success(buildCapability(ctx))
            }

            "listModels" -> {
                val ctx = appContext
                if (ctx == null) {
                    result.error("no_context", "Plugin context missing", null)
                    return
                }
                result.success(listCatalog(ctx))
            }

            "downloadModel" -> {
                val ctx = appContext
                val modelId = call.argument<String>("modelId")
                if (ctx == null || modelId.isNullOrBlank()) {
                    result.error("bad_args", "modelId required", null)
                    return
                }
                executor.execute {
                    try {
                        downloadModel(ctx, modelId)
                        runOnMain { result.success(null) }
                    } catch (error: Exception) {
                        Log.e(TAG, "downloadModel failed", error)
                        emitStatus(STATE_ERROR, message = error.message)
                        runOnMain { result.error("download_failed", error.message, null) }
                    }
                }
            }

            "cancelDownload" -> {
                cancelDownload.set(true)
                result.success(null)
            }

            "importModelZip" -> {
                val ctx = appContext
                val zipPath = call.argument<String>("zipPath")
                if (ctx == null || zipPath.isNullOrBlank()) {
                    result.error("bad_args", "zipPath required", null)
                    return
                }
                val modelId = call.argument<String>("modelId")
                val modelName = call.argument<String>("modelName")
                executor.execute {
                    try {
                        val imported = importModelZip(
                            ctx,
                            zipPath = zipPath,
                            requestedModelId = modelId,
                            requestedModelName = modelName,
                        )
                        runOnMain { result.success(imported) }
                    } catch (error: Exception) {
                        Log.e(TAG, "importModelZip failed", error)
                        emitStatus(STATE_ERROR, message = error.message)
                        runOnMain { result.error("import_failed", error.message, null) }
                    }
                }
            }

            "startModel" -> {
                val ctx = appContext
                val modelId = call.argument<String>("modelId")
                if (ctx == null || modelId.isNullOrBlank()) {
                    result.error("bad_args", "modelId required", null)
                    return
                }
                executor.execute {
                    try {
                        startGenerationModel(ctx, modelId)
                        runOnMain { result.success(statusMap()) }
                    } catch (error: Exception) {
                        Log.e(TAG, "startModel failed", error)
                        emitStatus(STATE_ERROR, modelId = modelId, message = error.message)
                        runOnMain { result.error("start_failed", error.message, null) }
                    }
                }
            }

            "stopModel" -> {
                executor.execute {
                    try {
                        stopGenerationBackend(emit = true)
                        runOnMain { result.success(statusMap()) }
                    } catch (error: Exception) {
                        runOnMain { result.error("stop_failed", error.message, null) }
                    }
                }
            }

            "getBackendStatus" -> result.success(statusMap())

            "generate" -> {
                val ctx = appContext
                if (ctx == null) {
                    result.error("no_context", "Plugin context missing", null)
                    return
                }
                if (statusState != STATE_READY || genProcess.get()?.isAlive != true) {
                    result.error("not_ready", "Local model is not loaded yet.", null)
                    return
                }
                val prompt = call.argument<String>("prompt") ?: ""
                if (prompt.isBlank()) {
                    result.error("bad_args", "prompt required", null)
                    return
                }
                val args = GenerateArgs(
                    prompt = prompt,
                    negativePrompt = call.argument<String>("negativePrompt") ?: "",
                    steps = call.argument<Int>("steps") ?: 20,
                    cfg = (call.argument<Number>("cfg")?.toDouble() ?: 7.0).toFloat(),
                    width = call.argument<Int>("width") ?: 512,
                    height = call.argument<Int>("height") ?: 512,
                    seed = call.argument<Int>("seed"),
                    scheduler = call.argument<String>("scheduler") ?: "dpm",
                )
                cancelGenerate.set(false)
                executor.execute {
                    try {
                        val out = runGenerate(args)
                        runOnMain { result.success(out) }
                    } catch (error: Exception) {
                        Log.e(TAG, "generate failed", error)
                        if (statusState == STATE_GENERATING) {
                            emitStatus(STATE_READY, modelId = statusModelId, modelName = statusModelName, message = "Ready")
                        }
                        runOnMain { result.error("generate_failed", error.message, null) }
                    }
                }
            }

            "stopGenerate" -> {
                cancelGenerate.set(true)
                result.success(null)
            }

            "ensureModel" -> {
                val ctx = appContext
                if (ctx == null) {
                    result.error("no_context", "Plugin context missing", null)
                    return
                }
                executor.execute {
                    try {
                        ensureUpscalerModelFile(ctx)
                        runOnMain { result.success(null) }
                    } catch (error: Exception) {
                        runOnMain { result.error("ensure_failed", error.message, null) }
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
                val targetScale = (call.argument<Int>("targetScale") ?: NATIVE_SCALE).coerceIn(1, NATIVE_SCALE)
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
                        runOnMain { result.error("upscale_failed", error.message, null) }
                    }
                }
            }

            "dispose" -> {
                executor.execute {
                    stopGenerationBackend(emit = false)
                    stopUpscaleBackend()
                    runOnMain { result.success(null) }
                }
            }

            else -> result.notImplemented()
        }
    }

    // --- Catalog / download -------------------------------------------------

    private fun listCatalog(context: Context): List<Map<String, Any?>> {
        val suffix = chipsetSuffix(deviceSoc()) ?: "min"
        val builtIn = CATALOG.map { entry ->
            val dir = modelDir(context, entry.id)
            val downloaded = isModelDirReady(dir)
            mapOf(
                "id" to entry.id,
                "name" to entry.name,
                "approximateSize" to entry.approximateSize,
                "fileUri" to entry.fileUri(suffix),
                "downloaded" to downloaded,
                "custom" to false,
                "defaultPrompt" to entry.defaultPrompt,
                "defaultNegativePrompt" to entry.defaultNegativePrompt,
            )
        }
        return builtIn + listCustomModels(context)
    }

    private fun listCustomModels(context: Context): List<Map<String, Any?>> {
        val root = File(context.filesDir, "models")
        if (!root.isDirectory) return emptyList()
        val catalogIds = CATALOG.map { it.id }.toSet()
        return root.listFiles()
            ?.asSequence()
            ?.filter { it.isDirectory && it.name !in catalogIds && isModelDirReady(it) }
            ?.map { dir ->
                mapOf(
                    "id" to dir.name,
                    "name" to dir.name,
                    "approximateSize" to "—",
                    "fileUri" to "",
                    "downloaded" to true,
                    "custom" to true,
                    "defaultPrompt" to "",
                    "defaultNegativePrompt" to "",
                )
            }
            ?.toList()
            ?: emptyList()
    }

    private fun isModelDirReady(dir: File): Boolean {
        if (!dir.isDirectory) return false
        return dir.listFiles()?.any { file ->
            file.isFile && file.name != "npucustom" && !file.name.startsWith(".")
        } == true
    }

    private fun downloadModel(context: Context, modelId: String) {
        val entry = CATALOG.firstOrNull { it.id == modelId }
            ?: throw IllegalArgumentException("Unknown model: $modelId")
        cancelDownload.set(false)
        val suffix = chipsetSuffix(deviceSoc()) ?: "min"
        val url = "https://huggingface.co/${entry.fileUri(suffix)}"
        val modelDir = modelDir(context, modelId)
        if (isModelDirReady(modelDir)) {
            emitStatus(statusState, modelId = statusModelId, modelName = statusModelName, message = statusMessage)
            return
        }
        emitStatus(STATE_DOWNLOADING, modelId = modelId, modelName = entry.name, progress = 0.0, message = "Downloading…")
        val tempDir = File(context.cacheDir, "qnn_model_dl")
        if (!tempDir.exists()) tempDir.mkdirs()
        val zipFile = File(tempDir, "$modelId.zip")
        val extractDir = File(tempDir, "${modelId}_extract")
        try {
            downloadToFileWithProgress(url, zipFile) { progress ->
                if (cancelDownload.get()) throw InterruptedException("Download cancelled")
                emitStatus(STATE_DOWNLOADING, modelId = modelId, modelName = entry.name, progress = progress * 0.9, message = "Downloading…")
            }
            if (cancelDownload.get()) throw InterruptedException("Download cancelled")
            emitStatus(STATE_DOWNLOADING, modelId = modelId, modelName = entry.name, progress = 0.92, message = "Extracting…")
            installExtractedModel(zipFile, modelDir, custom = false)
            emitStatus(STATE_IDLE, message = "Download complete")
        } finally {
            zipFile.delete()
            if (extractDir.exists()) extractDir.deleteRecursively()
        }
    }

    /**
     * Import a Local Dream–compatible NPU model zip already on disk.
     * Matches built-in catalog by zip prefix when possible; otherwise installs as custom.
     */
    private fun importModelZip(
        context: Context,
        zipPath: String,
        requestedModelId: String?,
        requestedModelName: String?,
    ): Map<String, Any?> {
        val zipFile = File(zipPath)
        if (!zipFile.isFile) {
            throw IllegalArgumentException("Zip not found: $zipPath")
        }

        val fileName = zipFile.name
        val matched = matchCatalogByZipName(fileName)
        val modelId = when {
            !requestedModelId.isNullOrBlank() -> sanitizeModelId(requestedModelId)
            matched != null -> matched.id
            else -> {
                val raw = requestedModelName?.takeIf { it.isNotBlank() }
                    ?: fileName.substringBeforeLast('.').substringBefore("_qnn")
                sanitizeModelId(raw).ifBlank { "custom_model" }
            }
        }
        val catalogEntry = CATALOG.firstOrNull { it.id == modelId }
        val isCustom = catalogEntry == null
        val modelName = when {
            !requestedModelName.isNullOrBlank() -> requestedModelName.trim()
            catalogEntry != null -> catalogEntry.name
            matched != null -> matched.name
            else -> modelId
        }

        emitStatus(
            STATE_DOWNLOADING,
            modelId = modelId,
            modelName = modelName,
            progress = 0.5,
            message = "Extracting…",
        )
        val modelDir = modelDir(context, modelId)
        installExtractedModel(zipFile, modelDir, custom = isCustom)
        emitStatus(STATE_IDLE, message = "Import complete")

        return mapOf(
            "id" to modelId,
            "name" to modelName,
            "approximateSize" to catalogEntry?.approximateSize.orEmpty().ifBlank { "—" },
            "fileUri" to "",
            "downloaded" to true,
            "custom" to isCustom,
            "defaultPrompt" to (catalogEntry?.defaultPrompt ?: ""),
            "defaultNegativePrompt" to (catalogEntry?.defaultNegativePrompt ?: ""),
        )
    }

    private fun installExtractedModel(zipFile: File, modelDir: File, custom: Boolean) {
        val extractDir = File(zipFile.parentFile ?: zipFile, "${zipFile.nameWithoutExtension}_extract")
        if (extractDir.exists()) extractDir.deleteRecursively()
        extractDir.mkdirs()
        try {
            unzipFlatten(zipFile, extractDir)
            if (modelDir.exists()) modelDir.deleteRecursively()
            modelDir.mkdirs()
            extractDir.listFiles()?.forEach { file ->
                file.renameTo(File(modelDir, file.name))
            }
            if (custom) {
                File(modelDir, "npucustom").createNewFile()
            }
            if (!isModelDirReady(modelDir)) {
                modelDir.deleteRecursively()
                throw IllegalStateException("Zip had no usable model files")
            }
        } finally {
            extractDir.deleteRecursively()
        }
    }

    private fun matchCatalogByZipName(fileName: String): CatalogEntry? {
        val base = fileName.substringAfterLast('/').substringBeforeLast('.')
        return CATALOG.firstOrNull { entry ->
            base.equals(entry.zipPrefix, ignoreCase = true) ||
                base.startsWith("${entry.zipPrefix}_", ignoreCase = true)
        }
    }

    private fun sanitizeModelId(raw: String): String {
        return raw.replace(" ", "")
            .replace(Regex("[^A-Za-z0-9._-]"), "")
            .trim()
    }

    // --- Generation backend -------------------------------------------------

    private fun resolveModel(context: Context, modelId: String): Pair<String, String> {
        val entry = CATALOG.firstOrNull { it.id == modelId }
        if (entry != null) {
            val dir = modelDir(context, modelId)
            if (!isModelDirReady(dir)) {
                throw IllegalStateException("Model not downloaded: ${entry.name}")
            }
            return entry.id to entry.name
        }
        val dir = modelDir(context, modelId)
        if (!isModelDirReady(dir)) {
            throw IllegalStateException("Model not downloaded: $modelId")
        }
        return modelId to modelId
    }

    private fun startGenerationModel(context: Context, modelId: String) {
        val (resolvedId, resolvedName) = resolveModel(context, modelId)
        val dir = modelDir(context, resolvedId)
        if (statusState == STATE_READY && statusModelId == resolvedId && genProcess.get()?.isAlive == true) {
            emitStatus(STATE_READY, modelId = resolvedId, modelName = resolvedName, progress = 1.0, message = "Ready")
            return
        }
        stopGenerationBackend(emit = false)
        emitStatus(STATE_STARTING, modelId = resolvedId, modelName = resolvedName, progress = 0.05, message = "Starting engine…")
        prepareRuntimeLibs(context)
        val executable = requireNativeExecutable(context)
        val runtimeDir = File(context.filesDir, RUNTIME_DIR)
        val command = listOf(
            executable.absolutePath,
            "--type", "sd15npu",
            "--model_dir", dir.absolutePath,
            "--lib_dir", runtimeDir.absolutePath,
            "--port", GEN_PORT.toString(),
            "--no_img2img",
        )
        val envPath = listOf(
            runtimeDir.absolutePath,
            "/system/lib64",
            "/vendor/lib64",
            "/vendor/lib64/egl",
        ).joinToString(":")
        Log.i(TAG, "Starting gen backend: ${command.joinToString(" ")}")
        emitStatus(STATE_LOADING, modelId = resolvedId, modelName = resolvedName, progress = 0.2, message = "Loading into memory…")
        val builder = ProcessBuilder(command).apply {
            directory(executable.parentFile)
            redirectErrorStream(true)
            environment()["LD_LIBRARY_PATH"] = envPath
            environment()["DSP_LIBRARY_PATH"] = runtimeDir.absolutePath
        }
        val process = builder.start()
        genProcess.set(process)
        Thread({
            try {
                process.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach { Log.i(TAG, "gen: $it") }
                }
            } catch (_: Exception) {
            }
        }, "qnn-gen-log").apply { isDaemon = true }.start()

        LocalQnnBackendService.start(context, resolvedName)

        val deadline = System.currentTimeMillis() + 180_000
        var tick = 0.2
        while (System.currentTimeMillis() < deadline) {
            if (process.isAlive != true) {
                throw IllegalStateException("Generation backend exited while loading")
            }
            if (waitForHealth(GEN_PORT, timeoutMs = 800)) {
                statusModelId = resolvedId
                statusModelName = resolvedName
                emitStatus(STATE_READY, modelId = resolvedId, modelName = resolvedName, progress = 1.0, message = "Ready")
                return
            }
            tick = (tick + 0.03).coerceAtMost(0.95)
            emitStatus(STATE_LOADING, modelId = resolvedId, modelName = resolvedName, progress = tick, message = "Loading into memory…")
        }
        stopGenerationBackend(emit = false)
        throw IllegalStateException("Timed out waiting for model to become ready")
    }

    private fun stopGenerationBackend(emit: Boolean) {
        val ctx = appContext
        if (emit) {
            emitStatus(STATE_STOPPING, modelId = statusModelId, modelName = statusModelName, message = "Releasing model…")
        }
        val process = genProcess.getAndSet(null)
        if (process != null) {
            try {
                process.destroy()
                if (!process.waitFor(5, TimeUnit.SECONDS)) {
                    process.destroyForcibly()
                }
            } catch (error: Exception) {
                Log.w(TAG, "Failed to stop gen backend", error)
            }
        }
        if (ctx != null) {
            try {
                LocalQnnBackendService.stop(ctx)
            } catch (_: Exception) {
            }
        }
        statusModelId = null
        statusModelName = null
        statusProgress = null
        if (emit) {
            emitStatus(STATE_IDLE, message = null)
        } else {
            statusState = STATE_IDLE
            statusMessage = null
        }
    }

    private fun runGenerate(args: GenerateArgs): Map<String, Any?> {
        emitStatus(STATE_GENERATING, modelId = statusModelId, modelName = statusModelName, progress = 0.0, message = "Generating…")
        val body = JSONObject().apply {
            put("prompt", args.prompt)
            put("negative_prompt", args.negativePrompt)
            put("steps", args.steps)
            put("cfg", args.cfg.toDouble())
            put("width", args.width)
            put("height", args.height)
            put("scheduler", mapScheduler(args.scheduler))
            put("show_diffusion_process", false)
            put("output_format", "jpeg")
            put("preview_format", "jpeg")
            args.seed?.let { put("seed", it) }
        }
        val url = URL("http://127.0.0.1:$GEN_PORT/generate")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 15_000
            readTimeout = 600_000
            setRequestProperty("Content-Type", "application/json")
        }
        try {
            conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            if (conn.responseCode !in 200..299) {
                val err = conn.errorStream?.bufferedReader()?.readText().orEmpty()
                throw IllegalStateException("Generate HTTP ${conn.responseCode}: ${err.take(300)}")
            }
            val reader = BufferedReader(InputStreamReader(conn.inputStream))
            var imageBytes: ByteArray? = null
            var seed: Int? = null
            while (true) {
                if (cancelGenerate.get()) throw InterruptedException("Generate cancelled")
                val line = reader.readLine() ?: break
                if (!line.startsWith("data: ")) continue
                val data = line.substring(6).trim()
                if (data == "[DONE]") break
                val json = JSONObject(data)
                when (json.optString("type")) {
                    "progress" -> {
                        val step = json.optInt("step")
                        val total = json.optInt("total_steps").coerceAtLeast(1)
                        val p = step.toDouble() / total
                        emitStatus(
                            STATE_GENERATING,
                            modelId = statusModelId,
                            modelName = statusModelName,
                            progress = p,
                            message = "Generating… $step/$total",
                        )
                    }
                    "complete" -> {
                        val b64 = json.optString("image")
                        if (b64.isEmpty()) throw IllegalStateException("Empty generate image")
                        imageBytes = Base64.decode(b64, Base64.DEFAULT)
                        val s = json.optLong("seed", -1)
                        if (s >= 0) seed = s.toInt()
                        // Prefer JPEG; if raw RGB, encode JPEG here.
                        if (json.optString("format", "jpeg") == "raw") {
                            val w = json.optInt("width", args.width)
                            val h = json.optInt("height", args.height)
                            imageBytes = rawRgbToJpeg(imageBytes!!, w, h)
                        }
                    }
                    "error" -> throw IllegalStateException(json.optString("message", "generate error"))
                }
            }
            val bytes = imageBytes ?: throw IllegalStateException("No image in generate stream")
            emitStatus(STATE_READY, modelId = statusModelId, modelName = statusModelName, progress = 1.0, message = "Ready")
            return mapOf(
                "bytes" to bytes,
                "seed" to seed,
                "width" to args.width,
                "height" to args.height,
                "format" to "jpg",
            )
        } finally {
            conn.disconnect()
        }
    }

    private fun rawRgbToJpeg(rgb: ByteArray, width: Int, height: Int): ByteArray {
        val expected = width * height * 3
        if (rgb.size < expected) throw IllegalStateException("Raw RGB size mismatch")
        val pixels = IntArray(width * height)
        for (i in pixels.indices) {
            val r = rgb[i * 3].toInt() and 0xFF
            val g = rgb[i * 3 + 1].toInt() and 0xFF
            val b = rgb[i * 3 + 2].toInt() and 0xFF
            pixels[i] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
        }
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    private fun mapScheduler(sampler: String): String {
        val s = sampler.lowercase()
        return when {
            s.contains("euler") -> "euler_a"
            else -> "dpm"
        }
    }

    // --- Upscale (existing) -------------------------------------------------

    private fun buildCapability(context: Context): Map<String, Any?> {
        val soc = deviceSoc()
        val qualcomm = isQualcommSoc(soc)
        val suffix = chipsetSuffix(soc)
        val hasRuntime = nativeExecutable(context)?.exists() == true
        val modelReady = upscalerModelFile(context).let { it.exists() && it.length() > 0L }
        val available = qualcomm && hasRuntime
        val reason = when {
            !qualcomm -> "Not a Qualcomm Snapdragon device ($soc)."
            !hasRuntime -> "Missing libstable_diffusion_core.so. Place it under jniLibs/arm64-v8a."
            else -> null
        }
        return capabilityMap(
            available = available,
            generationAvailable = available,
            soc = soc,
            modelSuffix = suffix,
            hasNativeRuntime = hasRuntime,
            modelReady = modelReady,
            reason = reason,
        )
    }

    private fun capabilityMap(
        available: Boolean,
        generationAvailable: Boolean = available,
        soc: String? = null,
        modelSuffix: String? = null,
        hasNativeRuntime: Boolean = false,
        modelReady: Boolean = false,
        reason: String? = null,
    ): Map<String, Any?> = mapOf(
        "available" to available,
        "generationAvailable" to generationAvailable,
        "soc" to soc,
        "modelSuffix" to modelSuffix,
        "hasNativeRuntime" to hasNativeRuntime,
        "modelReady" to modelReady,
        "reason" to reason,
    )

    private fun ensureUpscalerModelFile(context: Context) {
        val file = upscalerModelFile(context)
        if (file.exists() && file.length() > 0L) return
        file.parentFile?.mkdirs()
        val suffix = chipsetSuffix(deviceSoc()) ?: "min"
        val url =
            "https://huggingface.co/xororz/upscaler/resolve/main/" +
                "realesrgan_x4plus_anime_6b/upscaler_$suffix.bin"
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
        ensureUpscalerModelFile(context)
        prepareRuntimeLibs(context)
        ensureUpscaleBackendRunning(context)

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

        val jpeg = postUpscale(rgb, w, h, upscalerModelFile(context).absolutePath)
        if (targetScale == NATIVE_SCALE) return jpeg

        val decoded = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size) ?: return jpeg
        val scaled = Bitmap.createScaledBitmap(decoded, w * targetScale, h * targetScale, true)
        if (scaled !== decoded) decoded.recycle()
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 92, out)
        scaled.recycle()
        return out.toByteArray()
    }

    private fun postUpscale(rgb: ByteArray, width: Int, height: Int, upscalerPath: String): ByteArray {
        val url = URL("http://127.0.0.1:$UPSCALE_PORT/upscale")
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
                throw IllegalStateException("Upscale HTTP $code: ${body.toString(Charsets.UTF_8).take(300)}")
            }
            if (body.isEmpty()) throw IllegalStateException("Empty upscale response")
            return body
        } finally {
            conn.disconnect()
        }
    }

    private fun ensureUpscaleBackendRunning(context: Context) {
        val alive = upscaleProcess.get()?.isAlive == true
        if (alive && waitForHealth(UPSCALE_PORT, timeoutMs = 2_000)) return
        stopUpscaleBackend()
        startUpscaleBackend(context)
        if (!waitForHealth(UPSCALE_PORT, timeoutMs = 30_000)) {
            throw IllegalStateException("Upscaler backend failed to become healthy")
        }
    }

    private fun startUpscaleBackend(context: Context) {
        val executable = requireNativeExecutable(context)
        val runtimeDir = prepareRuntimeLibs(context)
        val command = listOf(
            executable.absolutePath,
            "--upscaler_mode",
            "--lib_dir",
            runtimeDir.absolutePath,
            "--port",
            UPSCALE_PORT.toString(),
        )
        val envPath = listOf(
            runtimeDir.absolutePath,
            "/system/lib64",
            "/vendor/lib64",
            "/vendor/lib64/egl",
        ).joinToString(":")
        val builder = ProcessBuilder(command).apply {
            directory(executable.parentFile)
            redirectErrorStream(true)
            environment()["LD_LIBRARY_PATH"] = envPath
            environment()["DSP_LIBRARY_PATH"] = runtimeDir.absolutePath
        }
        val process = builder.start()
        upscaleProcess.set(process)
        Thread({
            try {
                process.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach { Log.i(TAG, "upscale: $it") }
                }
            } catch (_: Exception) {
            }
        }, "qnn-upscale-log").apply { isDaemon = true }.start()
    }

    private fun stopUpscaleBackend() {
        val process = upscaleProcess.getAndSet(null) ?: return
        try {
            process.destroy()
            if (!process.waitFor(5, TimeUnit.SECONDS)) process.destroyForcibly()
        } catch (error: Exception) {
            Log.w(TAG, "Failed to stop upscaler backend", error)
        }
    }

    private fun waitForHealth(port: Int, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            try {
                val url = URL("http://127.0.0.1:$port/health")
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
                if (name.isBlank() || name == "README.md" || name == ".gitkeep") continue
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

    private fun requireNativeExecutable(context: Context): File {
        val file = nativeExecutable(context)
        if (file != null) return file
        val nativeDir = context.applicationInfo.nativeLibraryDir
        val listed = nativeDir
            ?.let { File(it).list()?.sorted()?.joinToString() }
            ?: "(none)"
        throw IllegalStateException(
            "Native executable not found ($EXECUTABLE_NAME). " +
                "nativeLibraryDir=$nativeDir contents=[$listed]. " +
                "Rebuild/reinstall the app so jniLibs are extracted " +
                "(useLegacyPackaging / extractNativeLibs).",
        )
    }

    private fun nativeExecutable(context: Context): File? {
        val candidates = mutableListOf<File>()
        context.applicationInfo.nativeLibraryDir?.let { dir ->
            candidates += File(dir, EXECUTABLE_NAME)
        }
        // Fallback copy under filesDir (in case APK libs are not executable in place).
        candidates += File(File(context.filesDir, "bin"), EXECUTABLE_NAME)

        for (candidate in candidates) {
            if (!candidate.isFile || candidate.length() <= 0L) continue
            candidate.setReadable(true, true)
            candidate.setExecutable(true, true)
            if (candidate.canExecute() || candidate.exists()) {
                return candidate
            }
        }

        // If the library exists in nativeLibraryDir but ProcessBuilder needs a
        // private copy, mirror it into filesDir/bin.
        val fromNative = context.applicationInfo.nativeLibraryDir
            ?.let { File(it, EXECUTABLE_NAME) }
        if (fromNative != null && fromNative.isFile && fromNative.length() > 0L) {
            val destDir = File(context.filesDir, "bin")
            if (!destDir.exists()) destDir.mkdirs()
            val dest = File(destDir, EXECUTABLE_NAME)
            try {
                fromNative.copyTo(dest, overwrite = true)
                dest.setReadable(true, true)
                dest.setExecutable(true, true)
                if (dest.isFile && dest.length() > 0L) return dest
            } catch (error: Exception) {
                Log.w(TAG, "Failed to copy native executable: ${error.message}")
            }
        }
        return null
    }

    private fun upscalerModelFile(context: Context): File {
        return File(File(context.filesDir, "upscalers/upscaler_anime"), MODEL_FILE)
    }

    private fun modelDir(context: Context, modelId: String): File {
        return File(File(context.filesDir, "models"), modelId)
    }

    private fun downloadToFile(url: String, target: File) {
        downloadToFileWithProgress(url, target, null)
    }

    private fun downloadToFileWithProgress(
        url: String,
        target: File,
        onProgress: ((Double) -> Unit)?,
    ) {
        val tmp = File(target.absolutePath + ".part")
        if (tmp.exists()) tmp.delete()
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 30_000
            readTimeout = 600_000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", "NativeTavern-QnnUpscale/0.1")
        }
        try {
            if (conn.responseCode !in 200..299) {
                throw IllegalStateException("Download HTTP ${conn.responseCode}")
            }
            val total = conn.contentLengthLong.takeIf { it > 0 } ?: -1L
            var read = 0L
            BufferedInputStream(conn.inputStream).use { input ->
                FileOutputStream(tmp).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        output.write(buffer, 0, n)
                        read += n
                        if (total > 0 && onProgress != null) {
                            onProgress(read.toDouble() / total)
                        }
                    }
                }
            }
            if (!tmp.renameTo(target)) {
                tmp.copyTo(target, overwrite = true)
                tmp.delete()
            }
            onProgress?.invoke(1.0)
        } finally {
            conn.disconnect()
        }
    }

    private fun unzipFlatten(zipFile: File, destDir: File) {
        ZipInputStream(BufferedInputStream(FileInputStream(zipFile))).use { zis ->
            var entry = zis.nextEntry
            while (entry != null) {
                if (!entry.isDirectory) {
                    val fileName = entry.name.substringAfterLast('/')
                    if (fileName.isNotEmpty() &&
                        !fileName.startsWith(".") &&
                        !fileName.startsWith("__MACOSX")
                    ) {
                        FileOutputStream(File(destDir, fileName)).use { output ->
                            zis.copyTo(output)
                        }
                    }
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
    }

    private fun statusMap(): Map<String, Any?> = mapOf(
        "state" to statusState,
        "modelId" to statusModelId,
        "modelName" to statusModelName,
        "progress" to statusProgress,
        "message" to statusMessage,
    )

    private fun emitStatus(
        state: String = statusState,
        modelId: String? = statusModelId,
        modelName: String? = statusModelName,
        progress: Double? = statusProgress,
        message: String? = statusMessage,
    ) {
        statusState = state
        statusModelId = modelId
        statusModelName = modelName
        statusProgress = progress
        statusMessage = message
        val snapshot = statusMap()
        runOnMain { eventSink?.success(snapshot) }
    }

    private fun runOnMain(block: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(block)
    }

    private data class GenerateArgs(
        val prompt: String,
        val negativePrompt: String,
        val steps: Int,
        val cfg: Float,
        val width: Int,
        val height: Int,
        val seed: Int?,
        val scheduler: String,
    )

    private data class CatalogEntry(
        val id: String,
        val name: String,
        val approximateSize: String,
        val zipPrefix: String,
        val defaultPrompt: String,
        val defaultNegativePrompt: String,
    ) {
        fun fileUri(suffix: String): String =
            "xororz/sd-qnn/resolve/main/${zipPrefix}_qnn2.28_$suffix.zip"
    }

    companion object {
        private const val TAG = "NtQnnUpscale"
        private const val CHANNEL = "native_tavern_qnn_upscale"
        private const val EVENT_CHANNEL = "native_tavern_qnn_upscale/events"
        private const val EXECUTABLE_NAME = "libstable_diffusion_core.so"
        private const val MODEL_FILE = "upscaler.bin"
        private const val RUNTIME_DIR = "qnn_upscale_runtime"
        private const val UPSCALE_PORT = 18081
        private const val GEN_PORT = 18080
        private const val NATIVE_SCALE = 4

        private const val STATE_IDLE = "idle"
        private const val STATE_DOWNLOADING = "downloading"
        private const val STATE_STARTING = "starting"
        private const val STATE_LOADING = "loading"
        private const val STATE_READY = "ready"
        private const val STATE_GENERATING = "generating"
        private const val STATE_STOPPING = "stopping"
        private const val STATE_ERROR = "error"

        private val NEG_ANIME =
            "lowres, bad anatomy, bad hands, missing fingers, extra fingers, bad arms, missing legs, missing arms, poorly drawn face, bad face, fused face, cloned face, three crus, fused feet, fused thigh, extra crus, ugly fingers, horn, realistic photo, huge eyes, worst face, 2girl, long fingers, disconnected limbs,"

        private val CATALOG = listOf(
            CatalogEntry(
                id = "anythingv5",
                name = "Anything V5.0",
                approximateSize = "1.1GB",
                zipPrefix = "AnythingV5",
                defaultPrompt = "masterpiece, best quality, 1girl, solo, cute, white hair,",
                defaultNegativePrompt = NEG_ANIME,
            ),
            CatalogEntry(
                id = "qteamix",
                name = "QteaMix",
                approximateSize = "1.1GB",
                zipPrefix = "QteaMix",
                defaultPrompt = "chibi, best quality, 1girl, solo, cute, pink hair,",
                defaultNegativePrompt = NEG_ANIME,
            ),
            CatalogEntry(
                id = "cuteyukimix",
                name = "CuteYukiMix",
                approximateSize = "1.1GB",
                zipPrefix = "CuteYukiMix",
                defaultPrompt = "masterpiece, best quality, 1girl, solo, cute, white hair,",
                defaultNegativePrompt = NEG_ANIME,
            ),
            CatalogEntry(
                id = "absolutereality",
                name = "Absolute Reality",
                approximateSize = "1.1GB",
                zipPrefix = "AbsoluteReality",
                defaultPrompt = "masterpiece, best quality, ultra-detailed, realistic, 8k, a cat on grass,",
                defaultNegativePrompt = "worst quality, low quality, normal quality, poorly drawn, lowres, low resolution, signature, watermarks, ugly, out of focus, error, blurry, unclear photo, bad photo, unrealistic, semi realistic, pixelated, cartoon, anime, cgi, drawing, 2d, 3d, censored, duplicate,",
            ),
            CatalogEntry(
                id = "chilloutmix",
                name = "ChilloutMix",
                approximateSize = "1.1GB",
                zipPrefix = "ChilloutMix",
                defaultPrompt = "RAW photo, best quality, realistic, photo-realistic, masterpiece, 1girl, upper body, facing front, portrait, white shirt",
                defaultNegativePrompt = "paintings, cartoon, anime, lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, cropped, worst quality, low quality, normal quality, jpeg artifacts, signature, watermark, username, skin spots, acnes, skin blemishes",
            ),
        )

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
