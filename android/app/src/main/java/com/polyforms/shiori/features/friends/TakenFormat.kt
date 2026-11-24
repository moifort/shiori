package com.polyforms.shiori.features.friends

import com.polyforms.shiori.shared.BookFormat

/** What its first volume is, which is the one a "+" takes. */
val FriendSaga.takenFormat: BookFormat
    get() = volumes.firstOrNull()?.format ?: if (isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK
