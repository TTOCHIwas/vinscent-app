package com.vinscent.vinscent.widgets

internal data class WidgetCalendarSummaryPresentation(
    val title: String,
    val additionalCount: Int,
)

internal object WidgetCalendarSummaryPolicy {
    fun resolve(
        title: String?,
        additionalCount: String?,
    ): WidgetCalendarSummaryPresentation? {
        val normalizedTitle = title?.trim().orEmpty()
        if (normalizedTitle.isEmpty()) return null

        return WidgetCalendarSummaryPresentation(
            title = normalizedTitle,
            additionalCount = additionalCount?.toIntOrNull()?.coerceAtLeast(0) ?: 0,
        )
    }
}
