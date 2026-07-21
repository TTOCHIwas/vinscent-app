package com.vinscent.vinscent.widgets

import java.io.File

internal object WidgetRecordingUploadPolicy {
    private const val MAXIMUM_DRAFT_BYTES = 4L * 1024L * 1024L
    private const val MAXIMUM_ATTEMPTS = 3

    fun isValidInput(
        recordingId: String?,
        filePath: String?,
        durationMs: Int,
    ): Boolean {
        return !recordingId.isNullOrBlank() &&
            !filePath.isNullOrBlank() &&
            durationMs in 1..WidgetRecordingDuration.MAXIMUM_MS
    }

    fun shouldRetry(retryable: Boolean, runAttemptCount: Int): Boolean {
        return retryable && runAttemptCount < MAXIMUM_ATTEMPTS - 1
    }

    fun isValidDraft(file: File, rootDirectory: File): Boolean {
        return runCatching {
            val canonicalFile = file.canonicalFile
            canonicalFile.isFile &&
                canonicalFile.length() in 1..MAXIMUM_DRAFT_BYTES &&
                isOwnedDraft(canonicalFile, rootDirectory)
        }.getOrDefault(false)
    }

    fun isOwnedDraft(file: File, rootDirectory: File): Boolean {
        return runCatching {
            val canonicalFile = file.canonicalFile
            val canonicalRoot = rootDirectory.canonicalFile
            canonicalFile.path.startsWith(canonicalRoot.path + File.separator)
        }.getOrDefault(false)
    }
}
