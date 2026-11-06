package com.polyforms.shiori.shared.platform

import android.content.Context
import android.content.Intent

/** Opens the share sheet on a text, as iOS's activity view does. */
fun Context.shareText(text: String) {
    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
    startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}
