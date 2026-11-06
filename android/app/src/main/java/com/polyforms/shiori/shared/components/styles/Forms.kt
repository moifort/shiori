package com.polyforms.shiori.shared.components.styles

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/** A section of an inset grouped form: a small caps header, white rows, a footer. */
@Composable
fun FormSection(
    header: String? = null,
    footer: String? = null,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = Shiori.colors
    Column(modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (header != null) {
            Text(header.uppercase(), style = Shiori.type.footnote, color = colors.secondaryLabel, modifier = Modifier.padding(start = 16.dp))
        }
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(26.dp)).background(colors.secondaryGroupedBackground), content = content)
        if (footer != null) {
            Text(footer, style = Shiori.type.footnote, color = colors.secondaryLabel, modifier = Modifier.padding(horizontal = 16.dp))
        }
    }
}

/** A row of a form section, with its hairline below unless it is the last. */
@Composable
fun FormRow(modifier: Modifier = Modifier, divider: Boolean = true, onClick: (() -> Unit)? = null, content: @Composable RowScope.() -> Unit) {
    Column {
        Row(
            modifier
                .fillMaxWidth()
                .heightIn(min = 52.dp)
                .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
        if (divider) ShioriDivider(Modifier.padding(start = 16.dp))
    }
}

/** A bare text field with a grey placeholder, as SwiftUI draws one inside a form row. */
@Composable
fun PlainTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    style: TextStyle = Shiori.type.body,
    keyboardType: KeyboardType = KeyboardType.Text,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.Sentences,
    singleLine: Boolean = true,
    minLines: Int = 1,
    maxLines: Int = if (singleLine) 1 else 6,
    textAlign: TextAlign = TextAlign.Start,
    focusRequester: FocusRequester? = null,
    onDone: (() -> Unit)? = null,
) {
    val colors = Shiori.colors
    Box(modifier) {
        if (value.isEmpty()) {
            Text(placeholder, style = style.copy(textAlign = textAlign), color = colors.tertiaryLabel, modifier = Modifier.fillMaxWidth())
        }
        BasicTextField(
            value,
            onValueChange,
            Modifier.fillMaxWidth().then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier),
            textStyle = style.copy(color = colors.label, textAlign = textAlign),
            cursorBrush = SolidColor(colors.accent),
            singleLine = singleLine,
            minLines = minLines,
            maxLines = maxLines,
            keyboardOptions = KeyboardOptions(capitalization = capitalization, keyboardType = keyboardType),
            keyboardActions = KeyboardActions(onDone = { onDone?.invoke() }),
        )
    }
}

/** A field on a grey rounded ground, as `.textFieldStyle(.roundedBorder)`. */
@Composable
fun RoundedTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    keyboardType: KeyboardType = KeyboardType.Text,
    focusRequester: FocusRequester? = null,
    leadingSymbol: String? = null,
    onDone: (() -> Unit)? = null,
) {
    val colors = Shiori.colors
    Row(
        modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(colors.secondaryGroupedBackground).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (leadingSymbol != null) Icon(Symbol(leadingSymbol), null, Modifier.size(20.dp), tint = colors.accent)
        PlainTextField(value, onValueChange, placeholder, Modifier.weight(1f), keyboardType = keyboardType, focusRequester = focusRequester, onDone = onDone)
    }
}

/** An iOS switch: green when on. */
@Composable
fun ShioriSwitch(checked: Boolean, onCheckedChange: (Boolean) -> Unit, enabled: Boolean = true) {
    val colors = Shiori.colors
    Switch(
        checked,
        onCheckedChange,
        enabled = enabled,
        colors = SwitchDefaults.colors(
            checkedThumbColor = Color.White,
            checkedTrackColor = colors.green,
            checkedBorderColor = colors.green,
            uncheckedThumbColor = Color.White,
            uncheckedTrackColor = colors.fill,
            uncheckedBorderColor = colors.fill,
        ),
        thumbContent = null,
    )
}
