import XCTest
import SwiftUI
@testable import BILCoachPresentation
#if canImport(UIKit)
import UIKit
#endif

final class CoachMarkdownTests: XCTestCase {
  private let markdown = """
  # Your BIL plan

  **Confirmed** facts, *clear* explanations and [a source](https://www.cdc.gov/).

  1. Review the saved plan.
  2. Confirm before recording anything.

  - No invented activity.
  - Keep your existing consent.

  | Exercise | Sets | Reps |
  | --- | --- | --- |
  | Saved movement | 3 | 8–12 |

  > General information, not a diagnosis.

  ```text
  No command is executed.
  ```
  """

  func testFoundationCreatesRealHeadingListsTableAndCode() {
    let blocks = BILCoachMarkdownDocument.blocks(markdown)
    XCTAssertEqual(blocks.first?.heading, 1)
    XCTAssertTrue(blocks.contains { $0.listOrdinal == 2 && !$0.unordered })
    XCTAssertTrue(blocks.contains { $0.unordered })
    XCTAssertTrue(blocks.contains { $0.quote })
    XCTAssertTrue(blocks.contains { $0.code })
    let cells = blocks.filter { $0.table != nil }
    XCTAssertEqual(cells.count, 6)
    XCTAssertEqual(cells.filter(\.headerCell).count, 3)
    XCTAssertEqual(Set(cells.map(\.column)), Set([0, 1, 2]))
    XCTAssertTrue(blocks.contains { block in
      block.text.runs.contains { $0.link?.host == "www.cdc.gov" }
    })
    XCTAssertTrue(blocks.contains { block in
      block.text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
    })
    XCTAssertTrue(blocks.contains { String($0.text.characters).contains("No command is executed.") })
  }

  func testDirectionUsesFirstStrongLetterAndPreservesNumbersUnitsAndEmoji() {
    XCTAssertTrue(BILCoachMarkdownDocument.rightToLeft("60 kg — وزني", fallback: false) == false)
    XCTAssertTrue(BILCoachMarkdownDocument.rightToLeft("60 — وزني 60 kg 🏃🏽‍♂️", fallback: false))
    XCTAssertFalse(BILCoachMarkdownDocument.rightToLeft("60 — My weight 60 كجم", fallback: true))
    XCTAssertTrue(BILCoachMarkdownDocument.rightToLeft("60 🥗", fallback: true))
    let text = "وزني ⁦60 kg⁩ — English 👨‍👩‍👧‍👦"
    XCTAssertEqual(String(BILCoachMarkdownDocument.blocks(text).first!.text.characters), text)
  }

  func testMalformedMarkdownRemainsReadableWithoutHTMLExecution() {
    let input = "## Heading\n\n**unfinished [link\n\n<script>not executed</script>"
    let blocks = BILCoachMarkdownDocument.blocks(input)
    XCTAssertFalse(blocks.isEmpty)
    XCTAssertTrue(blocks.contains { String($0.text.characters).contains("unfinished") })
  }

  func testArabicParagraphAfterATableIsNotDiscardedByParsing() {
    let text = "| التمرين | المجموعات | التكرارات |\n| --- | --- | --- |\n| حركة محفوظة | 3 | 8–12 |\n\nوزنك ⁦60 kg⁩ — English 🥗"
    let blocks = BILCoachMarkdownDocument.blocks(text)
    XCTAssertEqual(String(blocks.last!.text.characters), "وزنك ⁦60 kg⁩ — English 🥗")
    XCTAssertNil(blocks.last!.table)
  }

  #if canImport(UIKit)
  @MainActor func testActualSwiftUISurfacesInBothLanguagesThemesAndTextSizes() async throws {
    for arabic in [false, true] {
      for dark in [false, true] {
        for scale in [CGFloat(1), CGFloat(2)] {
          let text = arabic
            ? "# خطتك في BIL\n\n**معلومات مؤكدة** من خطتك، دون تسجيل تمرين منجز.\n\n1. راجع جلسة اليوم.\n2. أكّد التسجيل.\n\n| التمرين | المجموعات | التكرارات |\n| --- | --- | --- |\n| حركة محفوظة | 3 | 8–12 |\n\nوزنك ⁦60 kg⁩ — English 🥗"
            : markdown
          let name = "coach-swiftui-\(arabic ? "ar" : "en")-\(dark ? "dark" : "light")-\(Int(scale))x"
          var observedHeight: CGFloat = 0
          let view = BILCoachMarkdownView(
            blocks: BILCoachMarkdownDocument.blocks(text), rightToLeft: arabic,
            fontSize: 16 * scale,
            textColor: dark ? .white : Color(red: 0.078, green: 0.141, blue: 0.227),
            linkColor: Color(red: 0.02, green: 0.48, blue: 0.80),
            fontName: nil, openLink: { _ in XCTFail("Rendering must not open links.") },
            reportHeight: { observedHeight = $0 })
          let host = UIHostingController(rootView: view)
          let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
          window.overrideUserInterfaceStyle = dark ? .dark : .light
          window.rootViewController = host
          window.makeKeyAndVisible()
          host.view.frame = window.bounds
          host.view.backgroundColor = dark ? UIColor(red: 0.035, green: 0.09, blue: 0.13, alpha: 1) : UIColor(red: 0.94, green: 0.97, blue: 0.99, alpha: 1)
          host.view.setNeedsLayout()
          host.view.layoutIfNeeded()
          try await Task.sleep(nanoseconds: 100_000_000)
          XCTAssertGreaterThan(observedHeight, 100, "Real SwiftUI layout did not report its content height: \(name)")
          host.view.frame.size.height = observedHeight
          host.view.layoutIfNeeded()
          // A real UIHostingController adopts window safe-area changes on a
          // later layout pass. Wait for that pass and require stable native
          // height before capturing, rather than certifying a clipped image.
          try await Task.sleep(nanoseconds: 100_000_000)
          let settledHeight = observedHeight
          host.view.frame.size.height = settledHeight
          host.view.layoutIfNeeded()
          try await Task.sleep(nanoseconds: 100_000_000)
          XCTAssertEqual(observedHeight, settledHeight, accuracy: 0.5,
            "Native content height must stabilize before capture: \(name)")
          let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { context in
            host.view.layer.render(in: context.cgContext)
          }
          XCTAssertEqual(image.size.width, 390)
          XCTAssertGreaterThan(image.pngData()?.count ?? 0, 5000)
          let attachment = XCTAttachment(image: image)
          attachment.name = name
          attachment.lifetime = .keepAlways
          add(attachment)
          window.isHidden = true
          window.rootViewController = nil
        }
      }
    }
  }
  #endif
}
