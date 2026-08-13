package com.vinscent.vinscent.widgets

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetRecordingCachePolicyTest {
    @Test
    fun verifiedCacheIsPlayable() {
        assertTrue(
            WidgetRecordingCachePolicy.canPlay(
                manifest(freshness = WidgetRecordingCacheFreshness.VERIFIED),
            ),
        )
    }

    @Test
    fun requiredCacheIsPlayableOnlyWhenItsRecordingAlreadyMatches() {
        assertTrue(
            WidgetRecordingCachePolicy.canPlay(
                manifest(
                    freshness = WidgetRecordingCacheFreshness.REQUIRED,
                    requiredRecordingId = "recording-id",
                ),
            ),
        )
        assertFalse(
            WidgetRecordingCachePolicy.canPlay(
                manifest(
                    freshness = WidgetRecordingCacheFreshness.REQUIRED,
                    requiredRecordingId = "new-recording-id",
                ),
            ),
        )
    }

    @Test
    fun refreshRequiredCacheIsNotPlayable() {
        assertFalse(
            WidgetRecordingCachePolicy.canPlay(
                manifest(freshness = WidgetRecordingCacheFreshness.REFRESH_REQUIRED),
            ),
        )
    }

    private fun manifest(
        freshness: WidgetRecordingCacheFreshness,
        requiredRecordingId: String? = null,
    ) = WidgetRecordingCacheManifest(
        coupleId = "couple-id",
        cachedRecordingId = "recording-id",
        cachedRevision = 1,
        audioPath = "/cache/recording.m4a",
        freshness = freshness,
        requiredRecordingId = requiredRecordingId,
    )
}
