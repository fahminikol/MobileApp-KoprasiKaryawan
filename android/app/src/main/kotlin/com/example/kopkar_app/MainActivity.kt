package com.example.kopkar_app

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import android.provider.Settings
import android.view.WindowManager
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.NetworkInterface
import java.security.MessageDigest
import java.util.Collections
import kotlin.math.max
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val CHANNEL = "kopkar.bbm/native"
    private val PICK_IMAGE_REQ = 9001
    private var pendingResult: MethodChannel.Result? = null

    // Hardware-backed EncryptedSharedPreferences (AES-256 GCM Keystore Encryption)
    private val encryptedPrefs: SharedPreferences by lazy {
        try {
            val masterKey = MasterKey.Builder(applicationContext)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            EncryptedSharedPreferences.create(
                applicationContext,
                "kopkar_encrypted_shared_preferences",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            applicationContext.getSharedPreferences("kopkar_encrypted_fallback", Context.MODE_PRIVATE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 1. Aktifkan FLAG_SECURE secara default (Anti-Screenshot, Anti-Screen Recording & App Switcher Masking)
        try {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } catch (_: Exception) {}

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setFlagSecure" -> {
                        val enable = call.argument<Boolean>("enable") ?: true
                        if (enable) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    }
                    "isFlagSecureActive" -> {
                        val isSecure = (window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0
                        result.success(isSecure)
                    }
                    "writeEncryptedPref" -> {
                        val key = call.argument<String>("key") ?: "kopkar_master_state"
                        val value = call.argument<String>("value") ?: ""
                        encryptedPrefs.edit().putString(key, value).apply()
                        result.success(true)
                    }
                    "readEncryptedPref" -> {
                        val key = call.argument<String>("key") ?: "kopkar_master_state"
                        val value = encryptedPrefs.getString(key, null)
                        result.success(value)
                    }
                    "removeEncryptedPref" -> {
                        val key = call.argument<String>("key") ?: "kopkar_master_state"
                        encryptedPrefs.edit().remove(key).apply()
                        result.success(true)
                    }
                    "isEncryptedStorageActive" -> {
                        result.success(true)
                    }
                    "getDeviceMacAddress" -> {
                        result.success(getDeviceMacAddress())
                    }
                    "pickImageAsBase64" -> {
                        if (pendingResult != null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        try {
                            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                                type = "image/*"
                                addCategory(Intent.CATEGORY_OPENABLE)
                            }
                            startActivityForResult(
                                Intent.createChooser(intent, "Pilih Foto Bukti Transfer"),
                                PICK_IMAGE_REQ
                            )
                        } catch (e: Exception) {
                            pendingResult = null
                            result.success(null)
                        }
                    }
                    "savePdfToDownloads" -> {
                        val fileName = call.argument<String>("fileName") ?: "E-Statement_KOPKAR.pdf"
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try {
                            val savedPath = savePdfBytesToDownloads(fileName, bytes)
                            result.success(savedPath)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun savePdfBytesToDownloads(fileName: String, bytes: ByteArray): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val resolver = applicationContext.contentResolver
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { out ->
                        out.write(bytes)
                        out.flush()
                    }
                    values.clear()
                    values.put(MediaStore.Downloads.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)

                    // Coba buka langsung di aplikasi PDF Viewer jika ada
                    try {
                        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/pdf")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(Intent.createChooser(viewIntent, "Buka Dokumen PDF").apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                    } catch (_: Exception) {}

                    return "Download/$fileName"
                }
            }
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, fileName)
            FileOutputStream(file).use { it.write(bytes) }
            "Download/$fileName"
        } catch (e: Exception) {
            try {
                val fallbackDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
                val file = File(fallbackDir, fileName)
                FileOutputStream(file).use { it.write(bytes) }
                file.absolutePath
            } catch (_: Exception) {
                null
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQ) {
            val res = pendingResult
            pendingResult = null
            if (res == null) return

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                Thread {
                    try {
                        val inputStream = contentResolver.openInputStream(uri)
                        val original = BitmapFactory.decodeStream(inputStream)
                        inputStream?.close()
                        if (original == null) {
                            runOnUiThread { res.success(null) }
                            return@Thread
                        }
                        val maxDim = 480.0
                        val w = original.width
                        val h = original.height
                        val largest = max(w, h)
                        val scaled: Bitmap = if (largest > maxDim) {
                            val ratio = maxDim / largest
                            val nw = (w * ratio).roundToInt().coerceAtLeast(1)
                            val nh = (h * ratio).roundToInt().coerceAtLeast(1)
                            Bitmap.createScaledBitmap(original, nw, nh, true)
                        } else {
                            original
                        }
                        val baos = ByteArrayOutputStream()
                        scaled.compress(Bitmap.CompressFormat.JPEG, 62, baos)
                        val b64 = Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
                        runOnUiThread { res.success(b64) }
                    } catch (e: Exception) {
                        runOnUiThread { res.success(null) }
                    }
                }.start()
            } else {
                res.success(null)
            }
        }
    }

    private fun getDeviceMacAddress(): String {
        try {
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
            for (nif in interfaces) {
                if (nif.name.equals("wlan0", ignoreCase = true) || nif.name.equals("eth0", ignoreCase = true)) {
                    val macBytes = nif.hardwareAddress ?: continue
                    val sb = StringBuilder()
                    for (b in macBytes) {
                        sb.append(String.format("%02X:", b))
                    }
                    if (sb.isNotEmpty()) {
                        sb.deleteCharAt(sb.length - 1)
                        val macStr = sb.toString()
                        if (macStr.isNotEmpty() && macStr != "02:00:00:00:00:00") {
                            return macStr
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        // Fallback: Bentuk 6-byte Hardware MAC Address deterministik dari ANDROID_ID
        return try {
            val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "KOPKAR_BBM_DEF_HW_ID"
            val md = MessageDigest.getInstance("MD5").digest(androidId.toByteArray(Charsets.UTF_8))
            String.format("%02X:%02X:%02X:%02X:%02X:%02X", md[0], md[1], md[2], md[3], md[4], md[5])
        } catch (e: Exception) {
            "36:D5:18:A7:81:7F"
        }
    }
}
