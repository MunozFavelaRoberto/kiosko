package com.example.kiosko

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private val CHANNEL = "com.example.kiosko/screen"
	private var screenReceiver: BroadcastReceiver? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
			// no-op on Flutter->Native calls for now
		}

		// Register receiver to detect screen off / on events
		val filter = IntentFilter().apply {
			addAction(Intent.ACTION_SCREEN_OFF)
			addAction(Intent.ACTION_USER_PRESENT)
		}

		screenReceiver = object : BroadcastReceiver() {
			override fun onReceive(context: Context?, intent: Intent?) {
				val action = intent?.action ?: return
				val event = when (action) {
					Intent.ACTION_SCREEN_OFF -> "off"
					Intent.ACTION_USER_PRESENT -> "on"
					else -> "unknown"
				}
				try {
					MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("screenEvent", event)
				} catch (e: Exception) {
					// ignore
				}
			}
		}

		registerReceiver(screenReceiver, filter)
	}

	override fun onDestroy() {
		try {
			if (screenReceiver != null) unregisterReceiver(screenReceiver)
		} catch (e: Exception) {
			// ignore
		}
		super.onDestroy()
	}
}