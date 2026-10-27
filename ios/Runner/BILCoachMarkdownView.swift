import SwiftUI

struct BILCoachMarkdownView: View {
  let blocks: [BILCoachMarkdownBlock]
  let rightToLeft: Bool
  let fontSize: CGFloat
  let textColor: Color
  let linkColor: Color
  let fontName: String?
  let openLink: (URL) -> Void
  let reportHeight: (CGFloat) -> Void
  var reportFirstBlock: (CGRect) -> Void = { _ in }

  private var font: Font {
    if let name = fontName { return .custom(name, fixedSize: fontSize) }
    return .system(size: fontSize)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
        Group {
        if let table = block.table {
          if index == 0 || blocks[index - 1].table != table {
            tableView(blocks.filter { $0.table == table })
          }
        } else if block.rule {
          Divider().accessibilityHidden(true)
        } else {
          blockView(block)
        }
        }.background(GeometryReader { geometry in
          Color.clear.preference(key: BILCoachMarkdownFirstBlock.self,
            value: index == 0 ? geometry.frame(in: .named("bil-coach-markdown")) : .zero)
        })
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .fixedSize(horizontal: false, vertical: true)
    // Flutter already owns the screen safe area and keyboard. This view is
    // embedded inside a message, so UIKit window insets must not clip its
    // final paragraph or add a second status-bar inset to the native body.
    .ignoresSafeArea(.container)
    .coordinateSpace(name: "bil-coach-markdown")
    .foregroundColor(textColor)
    .tint(linkColor)
    .textSelection(.enabled)
    .environment(\.layoutDirection, rightToLeft ? .rightToLeft : .leftToRight)
    .environment(\.openURL, OpenURLAction { url in
      openLink(url)
      return .handled
    })
    .background(GeometryReader { geometry in
      Color.clear.preference(key: BILCoachMarkdownHeight.self,
                             value: geometry.size.height)
    })
    .onPreferenceChange(BILCoachMarkdownHeight.self, perform: reportHeight)
    .onPreferenceChange(BILCoachMarkdownFirstBlock.self, perform: reportFirstBlock)
  }

  @ViewBuilder private func blockView(_ block: BILCoachMarkdownBlock) -> some View {
    let plain = String(block.text.characters)
    let rtl = BILCoachMarkdownDocument.rightToLeft(plain, fallback: rightToLeft)
    HStack(alignment: .firstTextBaseline, spacing: 9) {
      if block.listOrdinal != nil {
        Text(block.unordered ? "•" : "\(block.listOrdinal!).")
          .font(font).accessibilityHidden(true)
      }
      Text(block.text)
        .font(block.heading > 0
          ? .system(size: fontSize * (block.heading == 1 ? 1.4 : 1.18), weight: .semibold)
          : block.code ? .system(size: fontSize, design: .monospaced) : font)
        .lineSpacing(5)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.leading, CGFloat(max(0, block.depth - 1)) * 14)
    .padding(block.code ? 12 : 0)
    .background(block.code ? textColor.opacity(0.055) : Color.clear)
    .overlay(alignment: .leading) {
      if block.quote {
        Rectangle().fill(linkColor.opacity(0.4)).frame(width: 2)
      }
    }
    .padding(.leading, block.quote ? 10 : 0)
    .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
  }

  private func tableView(_ cells: [BILCoachMarkdownBlock]) -> some View {
    let rows = Array(Set(cells.map(\.row))).sorted()
    return ScrollView(.horizontal, showsIndicators: true) {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(rows, id: \.self) { row in
          HStack(alignment: .top, spacing: 0) {
            ForEach(cells.filter { $0.row == row }.sorted { $0.column < $1.column }) { cell in
              Text(cell.text)
                .font(cell.headerCell ? font.weight(.semibold) : font)
                .frame(width: max(130, fontSize * 8), alignment: .leading)
                .padding(10)
                .environment(\.layoutDirection,
                  BILCoachMarkdownDocument.rightToLeft(String(cell.text.characters),
                    fallback: rightToLeft) ? .rightToLeft : .leftToRight)
            }
          }
          .background(row == rows.first ? linkColor.opacity(0.08) : Color.clear)
          Divider()
        }
      }
    }
    .accessibilityLabel(rightToLeft ? "جدول" : "Table")
  }
}

private struct BILCoachMarkdownHeight: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct BILCoachMarkdownFirstBlock: PreferenceKey {
  static var defaultValue = CGRect.zero
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    let next = nextValue()
    if value.isEmpty && !next.isEmpty { value = next }
  }
}

#if canImport(UIKit)
/// Measures the existing native body at Flutter's known width before its first
/// window frame. A zero-width UIKit attachment otherwise needs a second slow
/// cold layout before Flutter can reserve the complete reading surface.
enum BILCoachMarkdownSizing {
  static func prepare<Content: View>(_ host: UIHostingController<Content>,
                                    width: CGFloat) -> CGFloat? {
    guard width.isFinite, width > 0, width <= 10_000 else { return nil }
    host.view.frame.size.width = width
    let fitting: CGSize
    if #available(iOS 16.0, *) {
      fitting = host.sizeThatFits(in: CGSize(width: width, height: 100_000))
    } else {
      fitting = host.view.systemLayoutSizeFitting(
        CGSize(width: width, height: 100_000),
        withHorizontalFittingPriority: .required,
        verticalFittingPriority: .fittingSizeLevel)
    }
    guard fitting.height.isFinite, fitting.height > 0,
          fitting.height <= 100_000 else { return nil }
    host.view.frame.size.height = fitting.height
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    return fitting.height
  }
}
#endif
