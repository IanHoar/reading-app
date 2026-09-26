import ComposableArchitecture2
import DesignSystem
import SwiftUI

struct ReadingPanels: ViewModifier {
  let store: StoreOf<Reading>

  func body(content: Content) -> some View {
    content
      .overlay {
        if let authorization = store.authorization, authorization != .authorized {
          ListeningUnavailable(authorization: authorization) {
            store.send(.backToStoriesTapped)
          }
          .transition(.opacity)
        }
      }
      .overlay {
        if store.isConfirmingStop {
          StopReading(friend: store.friend) {
            store.send(.keepReadingTapped)
          } stop: {
            store.send(.backToStoriesTapped)
          }
          .transition(.opacity)
        }
      }
      .animation(.easeInOut(duration: 0.2), value: store.isConfirmingStop)
  }
}
