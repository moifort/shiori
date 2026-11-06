package com.polyforms.shiori.features.series

import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.features.library.LibraryMode
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.SeriesState

/** A saga named and authored, not yet catalogued: what an author page proposes to open. */
data class SeriesProposal(val name: String, val author: String)

/** What the Library tab's series shelf was asked to show. */
data class SeriesRequest(val mode: LibraryMode = LibraryMode.ALL, val state: SeriesState? = null)

/** A correction of the shared catalogue: its name, its format, its description. */
data class SeriesCorrection(val name: String? = null, val format: BookFormat? = null, val description: Change<String>? = null) {
    val isEmpty: Boolean get() = this == SeriesCorrection()
}
