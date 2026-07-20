package com.vinscent.vinscent.widgets

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
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
        val horizontalPadding = max(8, CHARACTER_FRAME_WIDTH / 48)
        val verticalPadding = max(12, CHARACTER_FRAME_HEIGHT / 12)
        val frame = Bitmap.createBitmap(
            CHARACTER_FRAME_WIDTH,
            CHARACTER_FRAME_HEIGHT,
            Bitmap.Config.ARGB_8888,
        )
        val activeScale = if (raised) 1.07f else 1f
        val fittedScale = minOf(
            (frame.width - horizontalPadding * 2).toFloat() / source.width,
            (frame.height - verticalPadding * 2).toFloat() / source.height,
        )
        val targetWidth = source.width * fittedScale * activeScale
        val targetHeight = source.height * fittedScale * activeScale
        val left = (frame.width - targetWidth) / 2f
        val restingTop = (frame.height - targetHeight) / 2f
        val lift = if (raised) verticalPadding * 0.45f else 0f
        val target = RectF(
            left,
            restingTop - lift,
            left + targetWidth,
            restingTop - lift + targetHeight,
        )
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        Canvas(frame).apply {
            drawColor(Color.WHITE)
            drawBitmap(source, null, target, paint)
        }
        return frame
    }

    private const val CHARACTER_FRAME_WIDTH = 384
    private const val CHARACTER_FRAME_HEIGHT = 480
}
