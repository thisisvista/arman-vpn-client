package com.vista.vpn

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Downloads and validates a Vista APK before handing it to Android's installer.
 * The installed app's signing certificate must match exactly; package name and
 * version are checked too. The caller is responsible for launching the installer.
 */
internal object ApkUpdate {
    private const val MAX_APK_BYTES = 250L * 1024 * 1024

    fun downloadAndVerify(context: Context, source: String): File {
        require(source.startsWith("https://")) { "Update URL must use HTTPS" }
        var currentUrl = URL(source)
        var redirects = 0
        var connection: HttpURLConnection? = null
        while (true) {
            val next = (currentUrl.openConnection() as HttpURLConnection).apply {
                connectTimeout = 20_000
                readTimeout = 30_000
                instanceFollowRedirects = false
                requestMethod = "GET"
                setRequestProperty("User-Agent", "Vista-VPN-Android")
            }
            next.connect()
            val status = next.responseCode
            if (status in 300..399) {
                val location = next.getHeaderField("Location")
                next.disconnect()
                check(!location.isNullOrBlank() && ++redirects <= 5) {
                    "APK download has too many or invalid redirects"
                }
                currentUrl = URL(currentUrl, location)
                check(currentUrl.protocol == "https") {
                    "Update redirected away from HTTPS"
                }
                continue
            }
            connection = next
            break
        }

        val activeConnection = connection ?: error("APK connection was not established")
        val apk = File(context.cacheDir, "updates/vista-update.apk")
        try {
            check(activeConnection.responseCode in 200..299) {
                "APK download failed (HTTP ${activeConnection.responseCode})"
            }
            val length = activeConnection.contentLengthLong
            check(length != 0L && length <= MAX_APK_BYTES) { "APK size is invalid" }
            apk.parentFile?.mkdirs()
            activeConnection.inputStream.use { input ->
                apk.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        check(total <= MAX_APK_BYTES) { "APK is too large" }
                        output.write(buffer, 0, count)
                    }
                    check(total > 0 && (length < 0 || total == length)) {
                        "APK download was incomplete"
                    }
                }
            }
        } catch (e: Exception) {
            apk.delete()
            throw e
        } finally {
            activeConnection.disconnect()
        }

        val flags = if (Build.VERSION.SDK_INT >= 28) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
        val candidate = context.packageManager.getPackageArchiveInfo(apk.absolutePath, flags)
            ?: throw IllegalArgumentException("Downloaded file is not a valid Android package")
        check(candidate.packageName == context.packageName) { "APK belongs to a different app" }

        @Suppress("DEPRECATION")
        val installed = context.packageManager.getPackageInfo(context.packageName, flags)
        val candidateSigners = if (Build.VERSION.SDK_INT >= 28) {
            candidate.signingInfo?.apkContentsSigners
        } else {
            candidate.signatures
        } ?: throw IllegalArgumentException("APK signing certificate is missing")
        val installedSigners = if (Build.VERSION.SDK_INT >= 28) {
            installed.signingInfo?.apkContentsSigners
        } else {
            installed.signatures
        } ?: throw IllegalStateException("Installed app signing certificate is unavailable")
        check(candidateSigners.size == installedSigners.size &&
            candidateSigners.all { candidateSigner ->
                installedSigners.any { it.toByteArray().contentEquals(candidateSigner.toByteArray()) }
            }) { "APK signature does not match this Vista installation" }

        val candidateVersion = if (Build.VERSION.SDK_INT >= 28) candidate.longVersionCode else {
            @Suppress("DEPRECATION")
            candidate.versionCode.toLong()
        }
        val installedVersion = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else {
            @Suppress("DEPRECATION")
            installed.versionCode.toLong()
        }
        check(candidateVersion > installedVersion) { "Downloaded APK is not a newer version" }
        return apk
    }
}
