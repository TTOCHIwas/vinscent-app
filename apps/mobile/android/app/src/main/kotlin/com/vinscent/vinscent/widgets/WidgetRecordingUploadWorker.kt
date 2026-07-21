package com.vinscent.vinscent.widgets

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.vinscent.vinscent.MainActivity
import com.vinscent.vinscent.R
import java.io.File
import java.util.concurrent.TimeUnit

class WidgetRecordingUploadWorker(
    context: Context,
    workerParameters: WorkerParameters,
) : CoroutineWorker(context, workerParameters) {
    override suspend fun doWork(): Result {
        val recordingId = inputData.getString(INPUT_RECORDING_ID)
        val filePath = inputData.getString(INPUT_FILE_PATH)
        val durationMs = inputData.getInt(INPUT_DURATION_MS, 0)
        if (!WidgetRecordingUploadPolicy.isValidInput(
                recordingId = recordingId,
                filePath = filePath,
                durationMs = durationMs,
            )
        ) {
            return finishFailure(filePath)
        }
        val validRecordingId = recordingId!!
        val validFilePath = filePath!!
        if (!WidgetRecordingUploadPolicy.isValidDraft(
                file = File(validFilePath),
                rootDirectory = draftDirectory(),
            )
        ) {
            return finishFailure(validFilePath)
        }

        val outcome = runCatching {
            WidgetRecordingFlutterBridge(applicationContext).upload(
                recordingId = validRecordingId,
                filePath = validFilePath,
                durationMs = durationMs,
            )
        }.getOrElse {
            WidgetRecordingUploadOutcome(success = false, retryable = true)
        }

        if (outcome.success) {
            File(validFilePath).delete()
            WidgetRecordingStateStore(applicationContext).markIdle()
            CharacterWidgetProvider.updateAll(applicationContext)
            return Result.success()
        }
        if (WidgetRecordingUploadPolicy.shouldRetry(
                retryable = outcome.retryable,
                runAttemptCount = runAttemptCount,
            )
        ) {
            return Result.retry()
        }
        return finishFailure(validFilePath)
    }

    private fun finishFailure(filePath: String?): Result {
        filePath?.let(::File)?.let { file ->
            runCatching {
                val canonicalFile = file.canonicalFile
                if (WidgetRecordingUploadPolicy.isOwnedDraft(
                        file = canonicalFile,
                        rootDirectory = draftDirectory(),
                    )
                ) {
                    canonicalFile.delete()
                }
            }
        }
        WidgetRecordingStateStore(applicationContext).markIdle()
        CharacterWidgetProvider.updateAll(applicationContext)
        showFailureNotification()
        return Result.failure()
    }

    private fun draftDirectory(): File =
        File(applicationContext.filesDir, DRAFT_DIRECTORY)

    private fun showFailureNotification() {
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    FAILURE_CHANNEL_ID,
                    applicationContext.getString(R.string.widget_recording_result_channel_name),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        val contentIntent = PendingIntent.getActivity(
            applicationContext,
            2404,
            Intent(applicationContext, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(applicationContext, FAILURE_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(applicationContext)
        }
        manager.notify(
            FAILURE_NOTIFICATION_ID,
            builder
                .setSmallIcon(R.drawable.ic_widget_notification)
                .setContentTitle(
                    applicationContext.getString(R.string.widget_recording_save_failed),
                )
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .build(),
        )
    }

    companion object {
        private const val INPUT_RECORDING_ID = "recording_id"
        private const val INPUT_FILE_PATH = "file_path"
        private const val INPUT_DURATION_MS = "duration_ms"
        private const val UNIQUE_WORK_NAME = "vinscent_widget_recording_upload"
        private const val DRAFT_DIRECTORY = "widget_recordings"
        private const val FAILURE_CHANNEL_ID = "vinscent_widget_recording_result"
        private const val FAILURE_NOTIFICATION_ID = 2403

        fun enqueue(
            context: Context,
            recordingId: String,
            filePath: String,
            durationMs: Int,
        ): Boolean {
            return runCatching {
                val constraints = Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
                val request = OneTimeWorkRequestBuilder<WidgetRecordingUploadWorker>()
                    .setInputData(
                        workDataOf(
                            INPUT_RECORDING_ID to recordingId,
                            INPUT_FILE_PATH to filePath,
                            INPUT_DURATION_MS to durationMs,
                        ),
                    )
                    .setConstraints(constraints)
                    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.SECONDS)
                    .build()
                WorkManager.getInstance(context).enqueueUniqueWork(
                    UNIQUE_WORK_NAME,
                    ExistingWorkPolicy.REPLACE,
                    request,
                )
            }.isSuccess
        }
    }
}
