/// Whether this build carries the Audible player. The one switch for the whole
/// feature: the play button on an audiobook, the accessory over the tab bar, the
/// full-screen player, and the background audio mode in Info.plist.
///
/// Set by the `SHIORI_AUDIBLE_PLAYER` build setting of the app target, on in
/// Debug and Release since 2026-11-24: App Store builds carry the player too.
/// Audible has not authorised a third-party player (App Store guidelines 5.2.2
/// and 5.2.3); the owner shipped it knowingly. Closing it again is one line:
/// `SHIORI_AUDIBLE_PLAYER = "";` in the Release configuration.
enum AudiblePlayerGate {
    #if AUDIBLE_PLAYER
    static let isOpen = true
    #else
    static let isOpen = false
    #endif
}
