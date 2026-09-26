import Content
import DesignSystem
import SwiftUI

struct StopReading: View {
  let friend: Friend
  let keepReading: () -> Void
  let stop: () -> Void

  var body: some View {
    ZStack {
      Paper.night.opacity(0.45)
        .ignoresSafeArea()
        .onTapGesture(perform: keepReading)
        .accessibilityHidden(true)
      VStack(spacing: 14) {
        PaperLabel(seed: 23) {
          Text("Stop reading?")
            .font(Typography.display(26))
            .foregroundStyle(Paper.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .rotationEffect(.degrees(-2))
        .accessibilityAddTraits(.isHeader)
        Text("\(friend.name) will wait here. You can come back to this story any time.")
          .font(Typography.ui(16, weight: .medium))
          .foregroundStyle(Paper.ink.opacity(0.85))
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        Button(action: keepReading) {
          Label("Keep reading", systemImage: "book.fill")
        }
        .buttonStyle(.paper)
        .padding(.top, 6)
        Button(action: stop) {
          Label("Back to stories", systemImage: "house.fill")
        }
        .buttonStyle(.paperQuiet)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 28)
      .frame(maxWidth: 340)
      .background {
        Deckle(seed: 31, jitter: 3, step: 12)
          .fill(Paper.paper)
          .shadow(color: Paper.shadow, radius: 12, y: 8)
      }
      .rotationEffect(.degrees(-1))
      .padding(.horizontal, 24)
    }
    .accessibilityElement(children: .contain)
  }
}

#if DEBUG
struct StopReadingPreview: View {
  var body: some View {
    ZStack {
      Color(hex: 0x8FCB6B)
      StopReading(friend: .bunny) {} stop: {}
    }
    .frame(width: Metrics.phone.reference.width, height: Metrics.phone.reference.height)
  }
}

#Preview { StopReadingPreview() }
#endif
