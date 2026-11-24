import SwiftUI

/// Puts the player's accessory in the tab view's bottom slot while a title is
/// playing or paused, and frees the slot otherwise.
struct PlayerAccessorySlot<Accessory: View>: ViewModifier {
    let player: AudiblePlayer
    @ViewBuilder let accessory: () -> Accessory

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: player.title != nil) {
                accessory().environment(player)
            }
        } else {
            // iOS 26.0 cannot free the slot: an empty capsule waits there
            // until something plays.
            content.tabViewBottomAccessory { accessory().environment(player) }
        }
    }
}
