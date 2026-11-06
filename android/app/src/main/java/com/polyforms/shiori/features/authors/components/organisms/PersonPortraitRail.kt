package com.polyforms.shiori.features.authors.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.plainClickable

/** A face for a rail of people: who, and their portrait. */
data class PortraitPerson(val id: String, val name: String, val initials: String, val portraitURL: String?)

private val portraitSize = 93.dp

/** People's portraits with their names under, scrolling sideways. */
@Composable
fun <Person> PersonPortraitRail(people: List<Person>, face: (Person) -> PortraitPerson, onOpen: (Person) -> Unit) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.Top,
    ) {
        items(people, key = { face(it).id }) { person ->
            val shown = face(person)
            Column(
                Modifier.width(portraitSize).plainClickable { onOpen(person) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                AuthorAvatar(shown.initials, shown.portraitURL, size = portraitSize)
                Text(
                    shown.name,
                    style = Shiori.type.footnote.copy(fontWeight = FontWeight.Medium),
                    color = Shiori.colors.label,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}
