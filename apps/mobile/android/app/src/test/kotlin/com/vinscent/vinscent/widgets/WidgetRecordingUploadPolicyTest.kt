package com.vinscent.vinscent.widgets

import java.nio.file.Files
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetRecordingUploadPolicyTest {
    @Test
    fun `upload input requires identifiers and a duration inside the recording limit`() {
        assertTrue(
            WidgetRecordingUploadPolicy.isValidInput(
                recordingId = "recording-1",
                filePath = "draft.m4a",
                durationMs = WidgetRecordingDuration.MAXIMUM_MS,
            ),
        )
        assertFalse(
            WidgetRecordingUploadPolicy.isValidInput(
                recordingId = "",
                filePath = "draft.m4a",
                durationMs = 1,
            ),
        )
        assertFalse(
            WidgetRecordingUploadPolicy.isValidInput(
                recordingId = "recording-1",
                filePath = "draft.m4a",
                durationMs = 0,
            ),
        )
        assertFalse(
            WidgetRecordingUploadPolicy.isValidInput(
                recordingId = "recording-1",
                filePath = "draft.m4a",
                durationMs = WidgetRecordingDuration.MAXIMUM_MS + 1,
            ),
        )
    }

    @Test
    fun `retryable uploads stop after three total attempts`() {
        assertTrue(
            WidgetRecordingUploadPolicy.shouldRetry(
                retryable = true,
                runAttemptCount = 0,
            ),
        )
        assertTrue(
            WidgetRecordingUploadPolicy.shouldRetry(
                retryable = true,
                runAttemptCount = 1,
            ),
        )
        assertFalse(
            WidgetRecordingUploadPolicy.shouldRetry(
                retryable = true,
                runAttemptCount = 2,
            ),
        )
        assertFalse(
            WidgetRecordingUploadPolicy.shouldRetry(
                retryable = false,
                runAttemptCount = 0,
            ),
        )
    }

    @Test
    fun `draft validation rejects empty files and sibling path prefixes`() {
        val parent = Files.createTempDirectory("widget-recording-policy").toFile()
        try {
            val root = parent.resolve("widget_recordings").apply { mkdirs() }
            val validDraft = root.resolve("valid.m4a").apply { writeBytes(byteArrayOf(1)) }
            val emptyDraft = root.resolve("empty.m4a").apply { createNewFile() }
            val sibling = parent.resolve("widget_recordings_other").apply { mkdirs() }
            val siblingDraft = sibling.resolve("outside.m4a").apply {
                writeBytes(byteArrayOf(1))
            }

            assertTrue(WidgetRecordingUploadPolicy.isValidDraft(validDraft, root))
            assertFalse(WidgetRecordingUploadPolicy.isValidDraft(emptyDraft, root))
            assertFalse(WidgetRecordingUploadPolicy.isValidDraft(siblingDraft, root))
        } finally {
            parent.deleteRecursively()
        }
    }
}
