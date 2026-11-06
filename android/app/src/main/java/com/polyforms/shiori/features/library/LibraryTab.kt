package com.polyforms.shiori.features.library

import androidx.compose.runtime.Composable
import com.polyforms.shiori.LocalAppRouter

/** The Library tab: its shelves, taking what the dashboard asked it to open. */
@Composable
fun LibraryTab() {
    val router = LocalAppRouter.current
    LibraryShelvesScreen(
        libraryRequest = router.libraryRequest,
        seriesRequest = router.seriesRequest,
        onRequestTaken = {
            router.libraryRequest = null
            router.seriesRequest = null
        },
    )
}
