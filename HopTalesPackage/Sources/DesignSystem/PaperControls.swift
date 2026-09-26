import SwiftUI

public struct PaperButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Typography.ui(18, weight: .semibold))
      .foregroundStyle(Paper.onRed)
      .padding(.horizontal, 28)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background {
        RoundedRectangle(cornerRadius: 28, style: .circular)
          .fill(Paper.rim)
          .shadow(color: Paper.shadow, radius: 5, y: 4)
        RoundedRectangle(cornerRadius: 24, style: .circular)
          .fill(Paper.red)
          .padding(4)
      }
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .opacity(isEnabled ? 1 : 0.5)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
      .animation(.easeInOut(duration: 0.15), value: isEnabled)
  }
}

extension ButtonStyle where Self == PaperButtonStyle {
  public static var paper: PaperButtonStyle { PaperButtonStyle() }
}

public struct PaperQuietButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Typography.ui(18, weight: .semibold))
      .foregroundStyle(Paper.ink)
      .padding(.horizontal, 28)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .paperChip(RoundedRectangle(cornerRadius: 28, style: .circular), rim: 4)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == PaperQuietButtonStyle {
  public static var paperQuiet: PaperQuietButtonStyle { PaperQuietButtonStyle() }
}

public struct PaperChipButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Typography.ui(15, weight: .semibold))
      .foregroundStyle(Paper.ink)
      .padding(.horizontal, 16)
      .frame(height: 42)
      .paperChip(Capsule(), rim: 3)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
  }
}

extension ButtonStyle where Self == PaperChipButtonStyle {
  public static var paperChip: PaperChipButtonStyle { PaperChipButtonStyle() }
}

public struct PaperChoice: View {
  let title: String
  let detail: String?
  let isSelected: Bool
  let action: () -> Void

  public init(
    title: String,
    detail: String? = nil,
    isSelected: Bool,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.detail = detail
    self.isSelected = isSelected
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(Typography.display(19))
          .foregroundStyle(Paper.ink)
        if let detail {
          Text(detail)
            .font(Typography.ui(14))
            .foregroundStyle(Paper.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .paperChoice(isSelected: isSelected)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

extension View {
  public func paperChoice(isSelected: Bool) -> some View {
    let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
    return frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(isSelected ? Paper.red.opacity(0.1) : Paper.rim.opacity(0.6), in: shape)
      .overlay(shape.strokeBorder(isSelected ? Paper.red : Paper.rim, lineWidth: 3))
      .shadow(color: Paper.shadow.opacity(0.5), radius: 3, y: 2)
      .contentShape(shape)
  }
}

public struct ProgressPills: View {
  let current: Int
  let count: Int

  public init(current: Int, count: Int) {
    self.current = current
    self.count = count
  }

  public var body: some View {
    HStack(spacing: 7) {
      ForEach(0..<count, id: \.self) { index in
        Capsule()
          .fill(index <= current ? Paper.red : Paper.muted.opacity(0.35))
          .frame(width: index == current ? 22 : 8, height: 8)
      }
    }
    .animation(.easeInOut(duration: 0.3), value: current)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Step \(current + 1) of \(count)")
  }
}

extension View {
  public func paperChip<S: InsettableShape>(
    _ shape: S,
    fill: Color = Paper.paper,
    rim: CGFloat = 4,
    shadow: CGFloat = 1
  ) -> some View {
    background(fill, in: shape)
      .overlay(shape.strokeBorder(Paper.rim, lineWidth: rim))
      .compositingGroup()
      .shadow(color: Paper.shadow, radius: 4 * shadow, y: 3 * shadow)
  }
}

public struct WashHighlight: View {
  public init() {}

  public var body: some View {
    Rectangle()
      .fill(
        EllipticalGradient(
          stops: [
            .init(color: Paper.wash.opacity(0.95), location: 0),
            .init(color: Paper.wash.opacity(0.75), location: 0.76),
            .init(color: Paper.wash.opacity(0), location: 1)
          ],
          center: .center,
          startRadiusFraction: 0,
          endRadiusFraction: 0.5
        )
      )
  }
}
