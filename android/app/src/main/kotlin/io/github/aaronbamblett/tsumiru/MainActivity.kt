package io.github.aaronbamblett.tsumiru

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Rect
import android.os.Build
import android.util.Log
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownActivity;

private const val MAX_TRANSCODE_PIXELS = 16_000_000L

class MainActivity: FlutterAndroidVolumeKeydownActivity() {
    private val stripExecutor = Executors.newSingleThreadExecutor()
    private val stripDecoders = mutableMapOf<String, Pair<BitmapRegionDecoder, MutableSet<String>>>()
    private val backgroundExecutor = Executors.newFixedThreadPool(3)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tsumiru/image_transcoder")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "transcodeFileToJpeg" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGS", "Path cannot be null", null)
                            return@setMethodCallHandler
                        }

                        val sourceFile = File(path)
                        if (!sourceFile.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
                            return@setMethodCallHandler
                        }

                        backgroundExecutor.execute {
                            val tempFile = File(sourceFile.parentFile, "${sourceFile.name}.tmp")
                            var decoded: Bitmap? = null
                            var flattened: Bitmap? = null
                            var success = false
                            try {
                                val source = ImageDecoder.createSource(sourceFile)
                                val bitmap = ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                                    // Software allocation bypasses Codec2 hardware limits
                                    decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                                    val pixels = info.size.width.toLong() * info.size.height
                                    if (pixels > MAX_TRANSCODE_PIXELS) {
                                        var sampleSize = 2
                                        while (pixels > MAX_TRANSCODE_PIXELS * sampleSize * sampleSize) {
                                            sampleSize *= 2
                                        }
                                        decoder.setTargetSampleSize(sampleSize)
                                    }
                                }
                                decoded = bitmap

                                // JPEG has no alpha, so transparent pixels would turn black
                                val opaque = if (bitmap.hasAlpha()) {
                                    flattenOnWhite(bitmap).also { flattened = it }
                                } else {
                                    bitmap
                                }

                                FileOutputStream(tempFile).use { out ->
                                    opaque.compress(Bitmap.CompressFormat.JPEG, 92, out)
                                }
                                success = tempFile.length() > 0L && tempFile.renameTo(sourceFile)
                            } catch (e: Throwable) {
                                success = false
                            } finally {
                                decoded?.recycle()
                                flattened?.recycle()
                                if (tempFile.exists()) {
                                    tempFile.delete()
                                }
                                runOnUiThread { result.success(success) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tsumiru/page_strips")
            .setMethodCallHandler { call, result ->
                if (call.method != "decodeStrip" && call.method != "release") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val owner = call.argument<String>("owner")
                if (path == null || owner == null) {
                    result.error("INVALID_ARGS", "Path and owner are required", null)
                    return@setMethodCallHandler
                }
                stripExecutor.execute {
                    try {
                        if (call.method == "release") {
                            stripDecoders[path]?.let { entry ->
                                entry.second.remove(owner)
                                if (entry.second.isEmpty()) {
                                    entry.first.recycle()
                                    stripDecoders.remove(path)
                                }
                            }
                            runOnUiThread { result.success(null) }
                        } else {
                            val top = call.argument<Int>("top") ?: -1
                            val height = call.argument<Int>("height") ?: 0
                            val entry = stripDecoders.getOrPut(path) {
                                Pair(
                                    requireNotNull(BitmapRegionDecoder.newInstance(path, false)),
                                    mutableSetOf()
                                )
                            }
                            entry.second.add(owner)
                            val decoder = entry.first
                            require(top >= 0 && height > 0 && height <= 4096 &&
                                top.toLong() + height <= decoder.height)
                            val options = BitmapFactory.Options().apply {
                                inPreferredConfig = Bitmap.Config.ARGB_8888
                                inScaled = false
                            }
                            val bitmap = requireNotNull(decoder.decodeRegion(
                                Rect(0, top, decoder.width, top + height), options
                            ))
                            val payload = try {
                                val pixels = IntArray(bitmap.width * bitmap.height)
                                bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
                                val rgba = ByteArray(pixels.size * 4)
                                for (i in pixels.indices) {
                                    val pixel = pixels[i]
                                    val offset = i * 4
                                    rgba[offset] = (pixel shr 16).toByte()
                                    rgba[offset + 1] = (pixel shr 8).toByte()
                                    rgba[offset + 2] = pixel.toByte()
                                    rgba[offset + 3] = (pixel ushr 24).toByte()
                                }
                                mapOf("rgba" to rgba, "width" to bitmap.width, "height" to bitmap.height)
                            } finally {
                                bitmap.recycle()
                            }
                            runOnUiThread { result.success(payload) }
                        }
                    } catch (e: Exception) {
                        stripDecoders.remove(path)?.first?.recycle()
                        runOnUiThread { result.error("STRIP_FAILED", e.message, null) }
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tsumiru/display_cutout")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setDrawUnderCutout" -> {
                        val enable = call.argument<Boolean>("enable") ?: false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            runOnUiThread {
                                val attrs = window.attributes
                                attrs.layoutInDisplayCutoutMode = if (enable) {
                                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                                } else {
                                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT
                                }
                                window.attributes = attrs
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Copy a reader page image to the system clipboard (Komikku parity —
        // ClipData.newUri on a FileProvider content:// URI, no re-encode).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tsumiru/clipboard")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "copyImage" -> {
                        try {
                            val path = call.argument<String>("path")!!
                            val uri = FileProvider.getUriForFile(
                                this, "$packageName.fileprovider", File(path)
                            )
                            val clip = ClipData.newUri(contentResolver, "image", uri)
                            val cm = getSystemService(Context.CLIPBOARD_SERVICE)
                                as ClipboardManager
                            cm.setPrimaryClip(clip)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("COPY_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tsumiru/eink")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceInfo" -> {
                        val socManufacturer = try {
                            Class.forName("android.os.SystemProperties")
                                .getMethod("get", String::class.java)
                                .invoke(null, "ro.soc.manufacturer") as? String
                        } catch (_: Throwable) {
                            null
                        }
                        result.success(mapOf(
                            "model" to Build.MODEL,
                            "manufacturer" to Build.MANUFACTURER,
                            "socManufacturer" to socManufacturer,
                        ))
                    }
                    "refreshScreen" -> result.success(probeEpdRefresh())
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        stripExecutor.execute {
            stripDecoders.values.forEach { it.first.recycle() }
            stripDecoders.clear()
        }
        stripExecutor.shutdown()
        super.onDestroy()
    }

    private fun flattenOnWhite(bitmap: Bitmap): Bitmap {
        val flat = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(flat)
        canvas.drawColor(Color.WHITE)
        canvas.drawBitmap(bitmap, 0f, 0f, null)
        return flat
    }

    /**
     * Reflection-probes vendor-patched EPD refresh APIs on android.view.View.
     * Meebook/Boyue (Rockchip) devices expose requestEpdMode(EPD_FULL, true).
     * Every step is guarded: false is a soft no-op on non-e-ink hardware.
     */
    private fun probeEpdRefresh(): Boolean {
        return try {
            val viewClass = android.view.View::class.java
            var epdFull = -1
            for (name in listOf("EPD_FULL", "EPD_FULL_SCREEN", "EPD_GC16")) {
                try {
                    epdFull = viewClass.getField(name).getInt(null)
                    break
                } catch (_: Throwable) {
                    // try the next constant name
                }
            }
            if (epdFull < 0) {
                Log.i("EinkRefresh", "no EPD_FULL constant on android.view.View")
                return false
            }
            val method = viewClass.getMethod(
                "requestEpdMode",
                Int::class.javaPrimitiveType,
                Boolean::class.javaPrimitiveType,
            )
            // MethodChannel handlers run on the platform main thread.
            method.invoke(window.decorView, epdFull, true)
            Log.i("EinkRefresh", "requestEpdMode($epdFull, true) invoked")
            true
        } catch (e: Throwable) {
            Log.i("EinkRefresh", "requestEpdMode unavailable: ${e.javaClass.simpleName}")
            false
        }
    }
}
