package com.polyforms.shiori.shared.components.molecules

import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.L

/**
 * What may be awaited of a book the reader does not hold, and what is: its translation and its
 * recording in the app's language, each watched for and announced the day it is out.
 */
class EditionWatch(offered: List<ReleaseFormat>, val awaited: Set<ReleaseFormat>) {
    /** Every edition the page offers to await, awaited or not, translation first. */
    val offered: List<ReleaseFormat> = ReleaseFormat.entries.filter { it in offered || it in awaited }

    /** Nothing to await and nothing awaited. */
    val isEmpty: Boolean get() = offered.isEmpty()

    override fun equals(other: Any?) = other is EditionWatch && other.offered == offered && other.awaited == awaited
    override fun hashCode() = offered.hashCode() * 31 + awaited.hashCode()
}

/** The edition as a menu names it. */
val ReleaseFormat.watchTitle: String get() = if (this == ReleaseFormat.BOOK) L("La traduction") else L("L'audio")

/** Its icon there. */
val ReleaseFormat.watchSymbol: String get() = if (this == ReleaseFormat.BOOK) "binoculars" else "headphones"

/** Its icon once awaited: the binoculars filled; the headphones have no filled form. */
val ReleaseFormat.awaitedSymbol: String get() = if (this == ReleaseFormat.BOOK) "binoculars.fill" else "headphones"
