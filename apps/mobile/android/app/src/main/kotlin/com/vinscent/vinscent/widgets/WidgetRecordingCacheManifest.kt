package com.vinscent.vinscent.widgets

import android.content.SharedPreferences
import org.json.JSONObject
import java.io.File

internal enum class WidgetRecordingCacheFreshness(val storedValue: String) {
    VERIFIED("verified"),
    REQUIRED("required"),
    REFRESH_REQUIRED("refresh_required"),
}

internal data class WidgetRecordingCacheManifest(
    val coupleId: String,
    val cachedRecordingId: String?,
    val cachedRevision: Int?,
    val audioPath: String?,
    val fileKey: String?,
    val freshness: WidgetRecordingCacheFreshness,
    val requiredRecordingId: String?,
    val generation: Int,
) {
    val hasCompleteCache: Boolean
        get() = cachedRecordingId != null && cachedRevision != null &&
            audioPath != null && fileKey != null
}

internal object WidgetRecordingCacheManifestParser {
    fun parse(raw: String?): WidgetRecordingCacheManifest? {
        if (raw.isNullOrBlank()) return null

        return runCatching {
            val json = JSONObject(raw)
            if (json.optInt("schemaVersion", -1) != 1) return null

            val coupleId = json.nonEmptyString("coupleId") ?: return null
            val freshnessValue = json.nonEmptyString("freshness") ?: return null
            val freshness = WidgetRecordingCacheFreshness.entries.firstOrNull {
                it.storedValue == freshnessValue
            } ?: return null
            val revision = json.optionalNonNegativeInt("cachedRevision")
            val generation = json.requiredNonNegativeInt("generation") ?: return null
            val manifest = WidgetRecordingCacheManifest(
                coupleId = coupleId,
                cachedRecordingId = json.nonEmptyString("cachedRecordingId"),
                cachedRevision = revision,
                audioPath = json.nonEmptyString("audioPath"),
                fileKey = json.nonEmptyString("fileKey"),
                freshness = freshness,
                requiredRecordingId = json.nonEmptyString("requiredRecordingId"),
                generation = generation,
            )
            if (manifest.isValid()) manifest else null
        }.getOrNull()
    }

    private fun WidgetRecordingCacheManifest.isValid(): Boolean {
        val hasNoCache = cachedRecordingId == null && cachedRevision == null &&
            audioPath == null && fileKey == null
        return when (freshness) {
            WidgetRecordingCacheFreshness.VERIFIED ->
                hasCompleteCache && requiredRecordingId == null
            WidgetRecordingCacheFreshness.REQUIRED ->
                requiredRecordingId != null && (hasCompleteCache || hasNoCache)
            WidgetRecordingCacheFreshness.REFRESH_REQUIRED ->
                requiredRecordingId == null && (hasCompleteCache || hasNoCache)
        }
    }

    private fun JSONObject.nonEmptyString(key: String): String? {
        if (isNull(key)) return null
        return optString(key).trim().takeIf(String::isNotEmpty)
    }

    private fun JSONObject.optionalNonNegativeInt(key: String): Int? {
        if (isNull(key) || !has(key)) return null
        return optInt(key, -1).takeIf { it >= 0 }
    }

    private fun JSONObject.requiredNonNegativeInt(key: String): Int? {
        if (isNull(key) || !has(key)) return null
        return optInt(key, -1).takeIf { it >= 0 }
    }
}

internal object WidgetRecordingCachePolicy {
    fun canPlay(manifest: WidgetRecordingCacheManifest?): Boolean {
        if (manifest?.hasCompleteCache != true) return false
        return when (manifest.freshness) {
            WidgetRecordingCacheFreshness.VERIFIED -> true
            WidgetRecordingCacheFreshness.REQUIRED ->
                manifest.requiredRecordingId == manifest.cachedRecordingId
            WidgetRecordingCacheFreshness.REFRESH_REQUIRED -> false
        }
    }
}

internal object WidgetRecordingCacheResolver {
    fun playableAudioPath(data: SharedPreferences): String? {
        val rawManifest = data.getString(WidgetStorageKeys.RECORDING_CACHE_MANIFEST, null)
        if (rawManifest == null) {
            return existingFile(data.getString(WidgetStorageKeys.RECORDING_AUDIO_PATH, null))
        }

        val manifest = WidgetRecordingCacheManifestParser.parse(rawManifest)
        if (!WidgetRecordingCachePolicy.canPlay(manifest)) return null
        return existingFile(manifest?.audioPath)
    }

    private fun existingFile(path: String?): String? {
        return path?.takeIf { it.isNotBlank() && File(it).isFile }
    }
}
