/// Whether this build carries the Audible player. The one switch for the whole
/// feature: the play button on an audiobook, the accessory over the tab bar, the
/// full-screen player, and the background audio mode in Info.plist.
///
/// Set by the `SHIORI_AUDIBLE_PLAYER` build setting of the app target: on in
/// Debug, off in Release, so no App Store build plays Audible titles — Audible
/// has not authorised a third-party player (App Store guidelines 5.2.2 and
/// 5.2.3). Opening it for every build is one line: `SHIORI_AUDIBLE_PLAYER =
/// AUDIBLE_PLAYER;` in the Release configuration too.
enum AudiblePlayerGate {
    #if AUDIBLE_PLAYER
    static let isOpen = true
    #else
    static let isOpen = false
    #endif
}
