package com.vinscent.vinscent.widgets

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import java.io.File
import kotlin.math.max

internal object WidgetBitmapLoader {
    fun decode(path: String?, maximumWidth: Int, maximumHeight: Int): Bitmap? {
        if (path.isNullOrBlank()) return null
        val file = File(path)
        if (!file.isFile) return null

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sampleSize = 1
        while (
            bounds.outWidth / sampleSize > maximumWidth * 2 ||
                bounds.outHeight / sampleSize > maximumHeight * 2
        ) {
            sampleSize *= 2
        }

        val decoded = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = Bitmap.Config.ARGB_8888
            },
        ) ?: return null

        if (decoded.width <= maximumWidth && decoded.height <= maximumHeight) {
            return decoded
        }

        val scale = minOf(
            maximumWidth.toFloat() / decoded.width,
            maximumHeight.toFloat() / decoded.height,
        )
        val scaled = Bitmap.createScaledBitmap(
            decoded,
            max(1, (decoded.width * scale).toInt()),
            max(1, (decoded.height * scale).toInt()),
            true,
        )
        if (scaled !== decoded) decoded.recycle()
        return scaled
    }

    fun characterFrame(source: Bitmap, raised: Boolean): Bitmap {
        val horizontalPadding = max(8, source.width / 48)
        val verticalPadding = max(12, source.height / 12)
        val frame = Bitmap.createBitmap(
            source.width + horizontalPadding * 2,
            source.height + verticalPadding * 2,
            Bitmap.Config.ARGB_8888,
        )
        val activeScale = if (raised) 1.07f else 1f
        val targetWidth = source.width * activeScale
        val targetHeight = source.height * activeScale
        val left = (frame.width - targetWidth) / 2f
        val restingTop = verticalPadding + (source.height - targetHeight) / 2f
        val lift = if (raised) verticalPadding * 0.45f else 0f
        val target = RectF(
            left,
            restingTop - lift,
            left + targetWidth,
            restingTop - lift + targetHeight,
        )
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        Canvas(frame).drawBitmap(source, null, target, paint)
        return frame
    }
}
