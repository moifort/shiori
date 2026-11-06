package com.polyforms.shiori.shared.platform

import android.annotation.SuppressLint
import android.net.Uri
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.polyforms.shiori.features.import.AmazonLogin
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.Shiori

/**
 * Amazon's own sign-in page in a web view the app throws away: the server's cookies set first,
 * the authorization code caught on the redirect and handed back, never the password.
 */
@SuppressLint("SetJavaScriptEnabled")
@Composable
fun AmazonSignInWebView(login: AmazonLogin, modifier: Modifier = Modifier, onCode: (String) -> Unit) {
    val answered = remember(login.url) { booleanArrayOf(false) }
    AndroidView({ context ->
        val cookies = CookieManager.getInstance()
        cookies.removeAllCookies(null)
        login.cookies.forEach { cookie -> cookies.setCookie("https://${cookie.domain.trimStart('.')}", "${cookie.name}=${cookie.value}; Domain=${cookie.domain}; Path=/; Secure") }
        cookies.flush()
        WebView(context).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    val url = request.url.toString()
                    if (!url.startsWith(login.redirectURL)) return false
                    val code = Uri.parse(url).getQueryParameter("openid.oa2.authorization_code") ?: return false
                    if (!answered[0]) {
                        answered[0] = true
                        onCode(code)
                    }
                    return true
                }
            }
            loadUrl(login.url)
        }
    }, modifier.fillMaxSize(), onRelease = { view ->
        view.destroy()
        CookieManager.getInstance().removeAllCookies(null)
    })
}

/** The sign-in page in a full-screen cover, with a way out. */
@Composable
fun AmazonSignInSheet(login: AmazonLogin, onCode: (String) -> Unit, onCancel: () -> Unit) {
    FullScreenCover(onCancel) {
        Column(Modifier.fillMaxSize().background(Shiori.colors.background)) {
            Box(Modifier.statusBarsPadding()) {
                SheetBar(L("Connexion Amazon"), leading = { ToolbarIconButton(L("Annuler"), "xmark", onClick = onCancel) })
            }
            AmazonSignInWebView(login, Modifier.fillMaxSize(), onCode)
        }
    }
}
