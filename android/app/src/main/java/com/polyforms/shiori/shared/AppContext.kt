package com.polyforms.shiori.shared

import android.content.Context

/** The application context, for the few singletons that need one (assets, caches, Firebase). */
object AppContext {
    private lateinit var context: Context
    fun set(value: Context) {
        context = value.applicationContext
    }
    fun get(): Context = context
}
