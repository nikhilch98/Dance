package com.example.nachna

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val DEEP_LINK_CHANNEL = "nachna/deep_links"
    private var pendingDeepLink: String? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(pendingDeepLink)
                    pendingDeepLink = null
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun handleIntent(intent: Intent?) {
        intent?.let {
            if (it.action == Intent.ACTION_VIEW) {
                val uri: Uri? = it.data
                uri?.let { deepLinkUri ->
                    val url = deepLinkUri.toString()
                    println("Deep link received: $url")
                    
                    // If Flutter engine is ready, send immediately
                    flutterEngine?.let { engine ->
                        MethodChannel(engine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL)
                            .invokeMethod("handleDeepLink", url)
                    } ?: run {
                        // Store for later if Flutter isn't ready yet
                        pendingDeepLink = url
                    }
                }
            }
        }
    }
}
