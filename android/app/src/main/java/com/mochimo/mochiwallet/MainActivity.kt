package com.mochimo.mochiwallet

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebResourceError
import android.webkit.SslErrorHandler
import android.net.http.SslError
import android.webkit.JavascriptInterface
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import org.json.JSONObject

class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private lateinit var walletBridge: WalletBridge

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        // Install splash screen (must be before super.onCreate)
        installSplashScreen()
        
        super.onCreate(savedInstanceState)
        
        // Enable edge-to-edge display and handle insets properly for Android 15+
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Set system bar colors to transparent
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.TRANSPARENT
        
        setContentView(R.layout.activity_main)

        walletBridge = WalletBridge(this)
        
        webView = findViewById(R.id.webview)
        setupWindowInsets()
        setupWebView()
        setupBackPressHandler()
        
        // Load the wallet application
        webView.loadUrl("file:///android_asset/index.html")
    }
    
    private fun setupWindowInsets() {
        val rootLayout = findViewById<androidx.constraintlayout.widget.ConstraintLayout>(R.id.root_layout)
        
        // Set light status bar and navigation bar icons to false (use white icons on dark background)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            isAppearanceLightStatusBars = false
            isAppearanceLightNavigationBars = false
        }
        
        // Handle system bars (status bar and navigation bar) insets
        ViewCompat.setOnApplyWindowInsetsListener(rootLayout) { view, windowInsets ->
            val insets = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars())
            
            // Apply padding to root layout to avoid content drawing behind system bars
            view.setPadding(
                insets.left,
                insets.top,
                insets.right,
                insets.bottom
            )
            
            windowInsets
        }
        // Request insets to be applied
        ViewCompat.requestApplyInsets(rootLayout)
    }
    
    private fun setupBackPressHandler() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (webView.canGoBack()) {
                    webView.goBack()
                } else {
                    showExitDialog()
                }
            }
        })
    }

    private fun setupWebView() {
        webView.apply {
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                databaseEnabled = true
                allowFileAccess = true
                allowContentAccess = true
                allowFileAccessFromFileURLs = true
                allowUniversalAccessFromFileURLs = true
                javaScriptCanOpenWindowsAutomatically = false
                setSupportMultipleWindows(false)
                
                // Enable modern web features
                mediaPlaybackRequiresUserGesture = false
                
                // Viewport and scaling settings for full-screen display
                useWideViewPort = true
                loadWithOverviewMode = true
                setSupportZoom(false)
                builtInZoomControls = false
                displayZoomControls = false
            }

            // Add JavaScript interface for native communication
            addJavascriptInterface(walletBridge, "AndroidBridge")
            
            // Set up WebView clients
            webViewClient = WalletWebViewClient()
            webChromeClient = WebChromeClient()

            // Enable dark mode support if available
            if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK)) {
                WebSettingsCompat.setForceDark(
                    settings,
                    WebSettingsCompat.FORCE_DARK_AUTO
                )
            }
        }
    }

    private fun showExitDialog() {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.exit_title)
            .setMessage(R.string.exit_confirmation)
            .setPositiveButton(R.string.exit) { _, _ ->
                finish()
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    override fun onDestroy() {
        webView.removeJavascriptInterface("AndroidBridge")
        webView.destroy()
        super.onDestroy()
    }

    inner class WalletWebViewClient : WebViewClient() {
        
        // SECURITY: Force external URLs to open in device browser, not in WebView
        // This prevents the permissive WebView settings from being exploited by external content
        override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
            val url = request?.url ?: return false
            val scheme = url.scheme?.lowercase() ?: ""
            
            // Allow local file:// URLs to load in WebView (required for wallet functionality)
            if (scheme == "file") {
                return false
            }
            
            // Force external http/https URLs to open in device browser
            if (scheme == "http" || scheme == "https") {
                try {
                    val intent = Intent(Intent.ACTION_VIEW, url)
                    startActivity(intent)
                } catch (e: Exception) {
                    android.util.Log.e("WalletWebView", "Failed to open external URL: $url", e)
                }
                return true // Prevent WebView from loading external URL
            }
            
            // Block all other schemes for security
            android.util.Log.w("WalletWebView", "Blocked URL with unsupported scheme: $url")
            return true
        }
        
        override fun onPageFinished(view: WebView?, url: String?) {
            super.onPageFinished(view, url)
            // Inject Android-specific initialization
            view?.evaluateJavascript("""
                window.IS_ANDROID = true;
                window.PLATFORM = 'android';
                console.log('Android bridge initialized');
            """.trimIndent(), null)
        }

        override fun onReceivedError(
            view: WebView?,
            request: WebResourceRequest?,
            error: WebResourceError?
        ) {
            super.onReceivedError(view, request, error)
            val errorCode = error?.errorCode ?: -1
            val description = error?.description?.toString() ?: "Unknown error"
            val url = request?.url?.toString() ?: "unknown"
            android.util.Log.e("WalletWebView", "Error loading $url: [$errorCode] $description")
            
            // Only show error for main frame failures
            if (request?.isForMainFrame == true) {
                view?.loadData(
                    """
                    <html><body style="font-family: sans-serif; padding: 20px; text-align: center;">
                        <h2>Failed to Load Wallet</h2>
                        <p>Error: $description</p>
                        <p style="color: #666; font-size: 12px;">Code: $errorCode</p>
                    </body></html>
                    """.trimIndent(),
                    "text/html",
                    "UTF-8"
                )
            }
        }

        override fun onReceivedHttpError(
            view: WebView?,
            request: WebResourceRequest?,
            errorResponse: WebResourceResponse?
        ) {
            super.onReceivedHttpError(view, request, errorResponse)
            val statusCode = errorResponse?.statusCode ?: -1
            val url = request?.url?.toString() ?: "unknown"
            android.util.Log.e("WalletWebView", "HTTP error $statusCode loading $url")
        }

        override fun onReceivedSslError(
            view: WebView?,
            handler: SslErrorHandler?,
            error: SslError?
        ) {
            // SECURITY: Always cancel SSL errors - never proceed with invalid certificates
            android.util.Log.e("WalletWebView", "SSL error: ${error?.primaryError} for ${error?.url}")
            handler?.cancel()
        }
    }
}

/**
 * Bridge class for communication between WebView JavaScript and native Android code
 */
class WalletBridge(private val activity: MainActivity) {
    
    @JavascriptInterface
    fun showToast(message: String) {
        activity.runOnUiThread {
            Toast.makeText(activity, message, Toast.LENGTH_SHORT).show()
        }
    }

    @JavascriptInterface
    fun log(message: String) {
        android.util.Log.d("WalletBridge", message)
    }

    @JavascriptInterface
    fun getDeviceInfo(): String {
        val info = JSONObject().apply {
            put("platform", "android")
            put("version", android.os.Build.VERSION.SDK_INT)
            put("model", android.os.Build.MODEL)
            put("manufacturer", android.os.Build.MANUFACTURER)
        }
        return info.toString()
    }

    @JavascriptInterface
    fun vibrate(duration: Int) {
        activity.runOnUiThread {
            val vibrator = activity.getSystemService(android.content.Context.VIBRATOR_SERVICE) 
                as android.os.Vibrator
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    android.os.VibrationEffect.createOneShot(
                        duration.toLong(),
                        android.os.VibrationEffect.DEFAULT_AMPLITUDE
                    )
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(duration.toLong())
            }
        }
    }
}
