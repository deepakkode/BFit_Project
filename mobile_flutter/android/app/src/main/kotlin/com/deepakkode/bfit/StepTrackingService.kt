package com.deepakkode.bfit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class StepTrackingService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private lateinit var sensorThread: HandlerThread
    private lateinit var sensorHandler: Handler
    private val mainHandler = Handler(Looper.getMainLooper())
    private var stepCounter: Sensor? = null
    private var userId: String? = null
    private var seededForStart = false

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sensorThread = HandlerThread("bfit-step-counter").apply { start() }
        sensorHandler = Handler(sensorThread.looper)
        createNotificationChannel()
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        val preferences = trackingPreferences()
        val requestedUserId = intent?.getStringExtra(EXTRA_USER_ID)
            ?: preferences.getString(KEY_USER_ID, null)
        if (requestedUserId.isNullOrBlank()) {
            stopTracking(this)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        userId = requestedUserId

        val today = utcDate()
        val sameUser = preferences.getString(KEY_USER_ID, null) == requestedUserId
        val sameDate = sameUser && preferences.getString(KEY_LOG_DATE, null) == today
        val existingSteps = preferences.getInt(KEY_STEPS, 0)
        val existingSeed = preferences.getInt(KEY_SEED_STEPS, 0)
        val seed = (intent?.getIntExtra(EXTRA_SEED_STEPS, 0) ?: 0).coerceAtLeast(0)
        seededForStart = !sameDate

        val steps = when {
            !sameUser -> seed
            sameDate -> existingSteps
            else -> 0
        }
        val seedSteps = when {
            !sameUser -> seed
            sameDate -> existingSeed
            else -> 0
        }
        val hasSensorBaseline = sameUser &&
            preferences.getBoolean(KEY_HAS_SENSOR_BASELINE, false)
        trackingPreferences().edit()
            .putString(KEY_USER_ID, requestedUserId)
            .putString(KEY_LOG_DATE, today)
            .putInt(KEY_STEPS, steps)
            .putInt(KEY_SEED_STEPS, seedSteps)
            .putBoolean(KEY_HAS_SENSOR_BASELINE, hasSensorBaseline)
            .putBoolean(KEY_ACTIVE, true)
            .putBoolean(KEY_AVAILABLE, true)
            .putString(KEY_MESSAGE, "Background step tracking is active.")
            .commit()

        stepCounter = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (stepCounter == null ||
            !sensorManager.registerListener(
                this,
                stepCounter,
                SensorManager.SENSOR_DELAY_NORMAL,
                sensorHandler,
            )
        ) {
            setUnavailable("This phone does not provide a usable step counter.")
            return START_NOT_STICKY
        }

        emitState(available = true, seeded = seededForStart)
        return START_STICKY
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_STEP_COUNTER || event.values.isEmpty()) return
        val preferences = trackingPreferences()
        if (!preferences.getBoolean(KEY_ACTIVE, false)) return
        val today = utcDate()
        val oldDate = preferences.getString(KEY_LOG_DATE, null)
        var steps = preferences.getInt(KEY_STEPS, 0)
        var seedSteps = preferences.getInt(KEY_SEED_STEPS, 0)
        var lastSensorTotal = preferences.getInt(KEY_LAST_SENSOR_TOTAL, 0)
        var hasBaseline = preferences.getBoolean(KEY_HAS_SENSOR_BASELINE, false)
        val sensorTotal = event.values[0].toLong().coerceAtLeast(0L)
            .coerceAtMost(Int.MAX_VALUE.toLong()).toInt()

        if (oldDate != today) {
            steps = 0
            seedSteps = 0
        }
        if (hasBaseline && sensorTotal >= lastSensorTotal) {
            steps += sensorTotal - lastSensorTotal
        } else if (!hasBaseline) {
            hasBaseline = true
        }
        lastSensorTotal = sensorTotal

        preferences.edit()
            .putString(KEY_LOG_DATE, today)
            .putInt(KEY_STEPS, steps)
            .putInt(KEY_SEED_STEPS, seedSteps)
            .putInt(KEY_LAST_SENSOR_TOTAL, lastSensorTotal)
            .putBoolean(KEY_HAS_SENSOR_BASELINE, hasBaseline)
            .putBoolean(KEY_ACTIVE, true)
            .putBoolean(KEY_AVAILABLE, true)
            .commit()
        emitState(available = true, seeded = false)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        sensorThread.quitSafely()
        isRunning = false
        super.onDestroy()
    }

    private fun setUnavailable(message: String) {
        sensorManager.unregisterListener(this)
        trackingPreferences().edit()
            .putBoolean(KEY_ACTIVE, false)
            .putBoolean(KEY_AVAILABLE, false)
            .putBoolean(KEY_HAS_SENSOR_BASELINE, false)
            .putString(KEY_MESSAGE, message)
            .commit()
        emitState(available = false, seeded = false, message = message)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun emitState(
        available: Boolean,
        seeded: Boolean,
        message: String = trackingPreferences().getString(KEY_MESSAGE, "") ?: "",
    ) {
        val preferences = trackingPreferences()
        val currentUser = userId ?: preferences.getString(KEY_USER_ID, null) ?: return
        val payload = mapOf(
                "type" to "steps",
                "user_id" to currentUser,
                "log_date" to (preferences.getString(KEY_LOG_DATE, utcDate()) ?: utcDate()),
                "steps" to preferences.getInt(KEY_STEPS, 0),
                "seed_steps" to preferences.getInt(KEY_SEED_STEPS, 0),
                "seeded" to seeded,
                "available" to available,
                "message" to message,
            )
        mainHandler.post { eventSink?.success(payload) }
    }

    private fun buildNotification(): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("BFit step tracking")
            .setContentText("Counting your steps in the background")
            .setContentIntent(openApp)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Background step tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Ongoing notification while BFit counts steps in the background."
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun trackingPreferences() =
        getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    private fun utcDate(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        return formatter.format(Date())
    }

    companion object {
        const val EXTRA_USER_ID = "user_id"
        const val EXTRA_SEED_STEPS = "seed_steps"
        private const val PREFERENCES_NAME = "bfit_background_steps"
        private const val CHANNEL_ID = "bfit_background_step_tracking"
        private const val NOTIFICATION_ID = 6021
        private const val KEY_USER_ID = "user_id"
        private const val KEY_LOG_DATE = "log_date"
        private const val KEY_STEPS = "steps"
        private const val KEY_SEED_STEPS = "seed_steps"
        private const val KEY_LAST_SENSOR_TOTAL = "last_sensor_total"
        private const val KEY_HAS_SENSOR_BASELINE = "has_sensor_baseline"
        private const val KEY_ACTIVE = "active"
        private const val KEY_AVAILABLE = "available"
        private const val KEY_MESSAGE = "message"

        @Volatile
        private var eventSink: EventChannel.EventSink? = null

        @Volatile
        private var isRunning = false

        fun setEventSink(sink: EventChannel.EventSink?) {
            eventSink = sink
        }

        fun publishCurrentState(context: Context) {
            if (!isRunning) return
            val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            eventSink?.success(
                mapOf(
                    "type" to "steps",
                    "user_id" to (preferences.getString(KEY_USER_ID, "") ?: ""),
                    "log_date" to (preferences.getString(KEY_LOG_DATE, "") ?: ""),
                    "steps" to preferences.getInt(KEY_STEPS, 0),
                    "seed_steps" to preferences.getInt(KEY_SEED_STEPS, 0),
                    "seeded" to false,
                    "available" to preferences.getBoolean(KEY_AVAILABLE, false),
                    "message" to (preferences.getString(KEY_MESSAGE, "") ?: ""),
                ),
            )
        }

        fun stopTracking(context: Context) {
            context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ACTIVE, false)
                .putBoolean(KEY_HAS_SENSOR_BASELINE, false)
                .commit()
            context.stopService(Intent(context, StepTrackingService::class.java))
        }
    }
}
