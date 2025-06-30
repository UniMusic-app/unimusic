package app.unimusic

import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.getcapacitor.Bridge
import com.getcapacitor.BridgeWebViewClient
import kotlin.math.roundToInt

/**
 * WebView Client which strips request of the HTTP Client Hint headers
 * Which are used (mostly) by Google to identify the users platform and its features
 *
 * See: [Client Hints](https://developer.mozilla.org/en-US/docs/Web/HTTP/Client_hints)
 *
 * On top of that it updates safe area insets, such that content can be properly displayed both as
 * edge-to-edge (SDK >= 35) as well as with proper margins on older devices (SDK < 35).
 */
class UniMusicWebViewClient(bridge: Bridge) : BridgeWebViewClient(bridge) {
    private var updateInsets: (() -> Unit)? = null
    private var bridge = bridge

    init {
        ViewCompat.setOnApplyWindowInsetsListener(
            bridge.webView,
            { view: View, insets: WindowInsetsCompat -> updateInsets(view, insets) }
        )
    }

    private fun stripClientHintsHeaders(request: WebResourceRequest) {
        val headers = request.requestHeaders
        val iterator = headers.entries.iterator()

        while (iterator.hasNext()) {
            val key: String = iterator.next()!!.key!!;

            if (
                key.equals("Referer", ignoreCase = true) ||
                key.equals("Origin", ignoreCase = true) ||
                key.equals("Sec-CH-UA", ignoreCase = true) ||
                key.equals("Sec-CH-UA-Mobile", ignoreCase = true) ||
                key.equals("Sec-CH-UA-Platform", ignoreCase = true)
            ) {
                iterator.remove()
            }
        }
    }

    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest): Boolean {
        stripClientHintsHeaders(request)
        return super.shouldOverrideUrlLoading(view, request)
    }

    override fun shouldInterceptRequest(
        view: WebView?,
        request: WebResourceRequest
    ): WebResourceResponse? {
        stripClientHintsHeaders(request)
        return super.shouldInterceptRequest(view, request)
    }

    override fun onPageFinished(view: WebView?, url: String?) {
        updateInsets?.let { it() }
        super.onPageFinished(view, url)
    }

    // Based on comments under https://github.com/ionic-team/capacitor/issues/7951
    private fun updateInsets(view: View?, windowInsets: WindowInsetsCompat): WindowInsetsCompat {
        val insets = windowInsets.getInsets(
            WindowInsetsCompat.Type.systemBars() or
                    WindowInsetsCompat.Type.displayCutout() or
                    WindowInsetsCompat.Type.ime()
        )

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            view?.let {
                val layoutParams = view.layoutParams as ViewGroup.MarginLayoutParams
                layoutParams.setMargins(insets.left, insets.top, insets.right, insets.bottom)
                view.layoutParams = layoutParams
            }
            return WindowInsetsCompat.CONSUMED
        }

        val density = bridge.activity.applicationContext.resources.displayMetrics.density

        val top = (insets.top / density).roundToInt()
        val right = (insets.right / density).roundToInt()
        val bottom = (insets.bottom / density).roundToInt()
        val left = (insets.left / density).roundToInt()

        // We store it as a function, so we can reuse it each time window loads a new page
        // to ensure safe area margins are available even after the window reloads
        updateInsets = {
            bridge.webView.evaluateJavascript(
                """{
            const rootElement = document.documentElement;
            if (rootElement) {
                rootElement.style.setProperty('--android-safe-area-top', '${top}px')
                rootElement.style.setProperty('--android-safe-area-bottom', '${bottom}px')
                rootElement.style.setProperty('--android-safe-area-left', '${left}px')
                rootElement.style.setProperty('--android-safe-area-right', '${right}px')
            }
            }""".trimIndent(), null
            )
        }

        return WindowInsetsCompat.CONSUMED
    }

}
