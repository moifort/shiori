package com.polyforms.shiori.shared

import android.content.Context
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import java.util.Locale

/**
 * The app's copy, looked up by the French text the iOS code writes — `L("À lire")` is
 * `String(localized: "À lire")`. The table is generated from the iOS catalogue
 * (`bun scripts/android-strings.ts`), so both apps say the same thing in the same words.
 *
 * French when the phone speaks French, English otherwise: English is the development
 * language, the fallback for every other language, as on iOS.
 */
object Strings {
    private var table: Map<String, JsonObject> = emptyMap()

    /** The language the app speaks: `fr` or `en`. */
    val appLanguage: String
        get() = if (Locale.getDefault().language == "fr") "fr" else "en"

    /**
     * The iOS catalogue, then the few strings only Android says (`strings.android.json`, kept by
     * hand: Google where iOS says Apple, Play where it says the App Store).
     */
    fun load(context: Context) {
        fun read(name: String): Map<String, JsonObject> = runCatching {
            val text = context.assets.open(name).bufferedReader().use { it.readText() }
            Json.parseToJsonElement(text).jsonObject.mapValues { it.value.jsonObject }
        }.getOrDefault(emptyMap())
        table = read("strings.json") + read("strings.android.json")
    }

    fun format(key: String, args: Array<out Any?>): String {
        val entry = table[key]
        val rendering: JsonElement? = entry?.get(appLanguage) ?: entry?.get("fr")
        val pattern = when (rendering) {
            is JsonPrimitive -> rendering.content
            is JsonObject -> plural(rendering, args)
            else -> key
        }
        return if (args.isEmpty()) unescape(pattern) else apply(pattern, args)
    }

    private fun plural(forms: JsonObject, args: Array<out Any?>): String {
        val count = args.firstOrNull { it is Number } as Number?
        val category = when {
            count == null -> "other"
            appLanguage == "fr" && (count.toLong() == 0L || count.toLong() == 1L) -> "one"
            appLanguage != "fr" && count.toLong() == 1L -> "one"
            else -> "other"
        }
        return ((forms[category] ?: forms["other"]) as? JsonPrimitive)?.content ?: ""
    }

    /** Swift's specifiers in Java's words: `%lld` → `%d`, `%@` → `%s`, positions kept. */
    private fun apply(pattern: String, args: Array<out Any?>): String {
        val java = pattern
            .replace(Regex("%(\\d+\\$)?ll?d")) { "%${it.groupValues[1]}d" }
            .replace(Regex("%(\\d+\\$)?@")) { "%${it.groupValues[1]}s" }
        val values = args.map { if (it is Int) it.toLong() else it }.toTypedArray()
        return try {
            String.format(Locale.getDefault(), java, *values)
        } catch (_: Exception) {
            java
        }
    }

    private fun unescape(pattern: String) = pattern.replace("%%", "%")
}

/** `String(localized:)`: the copy for a French key, with Swift-style arguments. */
fun L(key: String, vararg args: Any?): String = Strings.format(key, args)

/** The copy for a key that carries Markdown emphasis (`**…**`), drawn bold. */
fun LMarkdown(key: String, vararg args: Any?): AnnotatedString = markdown(Strings.format(key, args))

/** `**bold**` and `*italic*` spans, the Markdown SwiftUI's `Text` reads from a literal. */
fun markdown(text: String): AnnotatedString = buildAnnotatedString {
    var rest = text
    val bold = Regex("\\*\\*(.+?)\\*\\*")
    while (true) {
        val match = bold.find(rest) ?: break
        append(rest.substring(0, match.range.first))
        withStyle(SpanStyle(fontWeight = FontWeight.SemiBold)) { append(match.groupValues[1]) }
        rest = rest.substring(match.range.last + 1)
    }
    append(rest)
}
