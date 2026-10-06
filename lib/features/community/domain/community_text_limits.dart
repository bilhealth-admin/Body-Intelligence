/// Community body limits use Unicode code points, matching PostgreSQL
/// `char_length` for UTF-8 text. A joined emoji or a combining mark sequence
/// can contain several code points even when it looks like one character.
///
/// Counting never trims, normalizes, or truncates the user's text. Callers keep
/// their existing payload normalization and required-field rules separately.
abstract final class CommunityTextLimits {
  static const bodyCodePointLimit = 1200;

  static int count(String text) => text.runes.length;

  static bool exceedsBodyLimit(String text) => count(text) > bodyCodePointLimit;
}
