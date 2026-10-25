import Foundation

/// Presentation only. Foundation parses Markdown; this model has no transport,
/// persistence, commands, health calculations or credentials.
struct BILCoachMarkdownBlock: Identifiable {
  let id: Int
  var text: AttributedString
  var heading = 0
  var listOrdinal: Int?
  var unordered = false
  var depth = 0
  var quote = false
  var code = false
  var rule = false
  var table: Int?
  var row = 0
  var column = 0
  var headerCell = false
}

enum BILCoachMarkdownDocument {
  static func blocks(_ source: String) -> [BILCoachMarkdownBlock] {
    // No HTML engine, remote image fetch or model output execution. Preserve
    // unknown/malformed input as readable text rather than silently losing it.
    guard let attributed = try? AttributedString(
      markdown: source,
      options: .init(interpretedSyntax: .full,
                     failurePolicy: .returnPartiallyParsedIfPossible)
    ) else { return [.init(id: 0, text: AttributedString(source))] }
    var result: [BILCoachMarkdownBlock] = []
    for run in attributed.runs {
      let components = run.presentationIntent?.components ?? []
      let identity = components.first?.identity ?? 0
      var part = AttributedString(attributed[run.range])
      part.presentationIntent = nil // Native blocks supply block layout.
      // Images stay as their alternate description, never load a remote URL.
      if result.last?.id == identity {
        result[result.count - 1].text.append(part)
        continue
      }
      var block = BILCoachMarkdownBlock(id: identity, text: part)
      for component in components {
        switch component.kind {
        case .header(let level): block.heading = level
        case .listItem(let ordinal): block.listOrdinal = ordinal
        case .unorderedList: block.unordered = true; block.depth += 1
        case .orderedList: block.depth += 1
        case .blockQuote: block.quote = true
        case .codeBlock: block.code = true
        case .thematicBreak: block.rule = true
        case .table: block.table = component.identity
        case .tableHeaderRow: block.headerCell = true; block.row = 0
        case .tableRow(let index): block.row = index
        case .tableCell(let index): block.column = index
        default: break
        }
      }
      result.append(block)
    }
    return result.isEmpty && !source.isEmpty
      ? [.init(id: 0, text: AttributedString(source))] : result
  }

  /// First strong script per paragraph/cell; digits and punctuation do not
  /// choose direction. Foundation retains Unicode bidi within the same line.
  static func rightToLeft(_ text: String, fallback: Bool) -> Bool {
    for scalar in text.unicodeScalars {
      guard CharacterSet.letters.contains(scalar) else { continue }
      let value = scalar.value
      return (0x0590...0x08FF).contains(value)
        || (0xFB1D...0xFDFF).contains(value)
        || (0xFE70...0xFEFF).contains(value)
        || (0x1EE00...0x1EEFF).contains(value)
    }
    return fallback
  }
}
