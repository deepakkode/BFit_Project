package com.deepakkode.bfit

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STEP_METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val userId = call.argument<String>("user_id")
                        if (userId.isNullOrBlank()) {
                            result.error("invalid_user", "A signed-in user is required.", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(this, StepTrackingService::class.java)
                            .putExtra(StepTrackingService.EXTRA_USER_ID, userId)
                            .putExtra(
                                StepTrackingService.EXTRA_SEED_STEPS,
                                call.argument<Int>("seed_steps") ?: 0,
                            )
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (error: SecurityException) {
                            result.error(
                                "service_permission_denied",
                                error.message ?: "Android denied the step tracking service.",
                                null,
                            )
                        } catch (error: IllegalStateException) {
                            result.error(
                                "service_start_denied",
                                error.message ?: "Android could not start step tracking.",
                                null,
                            )
                        }
                    }

                    "stop" -> {
                        StepTrackingService.stopTracking(this)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STEP_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    StepTrackingService.setEventSink(events)
                    StepTrackingService.publishCurrentState(this@MainActivity)
                }

                override fun onCancel(arguments: Any?) {
                    StepTrackingService.setEventSink(null)
                }
            })
    }

    companion object {
        private const val STEP_METHOD_CHANNEL = "com.deepakkode.bfit/step_tracking"
        private const val STEP_EVENT_CHANNEL = "com.deepakkode.bfit/step_updates"
    }
}
