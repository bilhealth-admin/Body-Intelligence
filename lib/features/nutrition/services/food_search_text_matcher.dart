import 'food_search_normalizer.dart';

/// Ordered, boundary-safe text match used by every meal-search source.
///
/// A user can discover a food after every additional character. Once the
/// result set contains a whole-token match, [suppressIncompleteTokenPrefixes]
/// removes longer-token false positives. For example, `appl` still discovers
/// `Apple`, while `apple` keeps `Apple`/`Apples` and drops `Applebees`.
enum FoodSearchTextMatchTier {
  none,
  keywordOrContains,
  wordPrefix,
  primaryPhrasePrefix,
  exact,
}

enum FoodSearchTextField { primaryName, arabicName, category, keyword }

class FoodSearchTextMatch {
  const FoodSearchTextMatch({
    this.tier = FoodSearchTextMatchTier.none,
    this.field,
    this.completesQueryTokens = false,
    this.usesIncompleteTokenPrefix = false,
    this.closesIncompleteTokenPrefixes = false,
  });

  final FoodSearchTextMatchTier tier;
  final FoodSearchTextField? field;
  final bool completesQueryTokens;
  final bool usesIncompleteTokenPrefix;
  final bool closesIncompleteTokenPrefixes;

  bool get matches => tier != FoodSearchTextMatchTier.none;

  int get rank => tier.index;
}

class FoodSearchTextMatcher {
  const FoodSearchTextMatcher();

  /// Suppresses semantic false positives only when this result set proves the
  /// query is already a complete token. This is intentionally data-driven;
  /// it works for foods absent from any authored lexicon (for example `pear`).
  /// One- and two-rune tokens never close the set, because source labels often
  /// contain articles or abbreviations such as `a` while the user is still
  /// entering a longer food name.
  List<T> suppressIncompleteTokenPrefixes<T>(
    Iterable<T> candidates,
    FoodSearchTextMatch Function(T candidate) matchOf,
  ) {
    final materialized = candidates.toList(growable: false);
    final hasCompleteMatch = materialized.any(
      (candidate) => matchOf(candidate).closesIncompleteTokenPrefixes,
    );
    if (!hasCompleteMatch) return materialized;
    return materialized
        .where((candidate) => !matchOf(candidate).usesIncompleteTokenPrefix)
        .toList(growable: false);
  }

  FoodSearchTextMatch match({
    required String query,
    required String primaryName,
    String? arabicName,
    String? category,
    Iterable<String> keywords = const <String>[],
    Iterable<String> queryVariants = const <String>[],
  }) {
    final variants = <String>{
      FoodSearchNormalizer.normalize(query),
      ...queryVariants.map(FoodSearchNormalizer.normalize),
    }..removeWhere((value) => value.isEmpty);
    if (variants.isEmpty) return const FoodSearchTextMatch();

    final primary = FoodSearchNormalizer.normalize(primaryName);
    final arabic = FoodSearchNormalizer.normalize(arabicName ?? '');
    final normalizedCategory = FoodSearchNormalizer.normalize(category ?? '');
    final normalizedKeywords = keywords
        .map(FoodSearchNormalizer.normalize)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    var best = const FoodSearchTextMatch();
    for (final variant in variants) {
      best = _better(
        best,
        _matchNamedField(primary, variant, FoodSearchTextField.primaryName),
      );
      best = _better(
        best,
        _matchNamedField(arabic, variant, FoodSearchTextField.arabicName),
      );
      best = _better(
        best,
        _matchMetadataField(
          normalizedCategory,
          variant,
          FoodSearchTextField.category,
        ),
      );
      for (final keyword in normalizedKeywords) {
        best = _better(
          best,
          _matchMetadataField(keyword, variant, FoodSearchTextField.keyword),
        );
      }
    }
    return best;
  }

  FoodSearchTextMatch _matchNamedField(
    String candidate,
    String query,
    FoodSearchTextField field,
  ) {
    if (candidate.isEmpty) return const FoodSearchTextMatch();
    if (candidate == query) {
      return FoodSearchTextMatch(
        tier: FoodSearchTextMatchTier.exact,
        field: field,
        completesQueryTokens: true,
        closesIncompleteTokenPrefixes: true,
      );
    }

    final candidateTokens = _tokens(candidate);
    final queryTokens = _tokens(query);
    if (candidateTokens.isEmpty || queryTokens.isEmpty) {
      return const FoodSearchTextMatch();
    }

    if (_matchesPhrasePrefix(candidateTokens, queryTokens)) {
      final usesIncompletePrefix = _phraseUsesIncrementalPrefix(
        candidateTokens,
        queryTokens,
      );
      return FoodSearchTextMatch(
        tier: FoodSearchTextMatchTier.primaryPhrasePrefix,
        field: field,
        completesQueryTokens: !usesIncompletePrefix,
        usesIncompleteTokenPrefix: usesIncompletePrefix,
        closesIncompleteTokenPrefixes:
            !usesIncompletePrefix && _hasSemanticQueryTokens(queryTokens),
      );
    }

    var usedIncrementalPrefix = false;
    final unmatched = candidateTokens.toList(growable: true);
    for (final queryToken in queryTokens) {
      final index = unmatched.indexWhere(
        (candidateToken) => _matchesWholeToken(candidateToken, queryToken),
      );
      if (index >= 0) {
        unmatched.removeAt(index);
        continue;
      }
      final prefixIndex = unmatched.indexWhere(
        (candidateToken) =>
            _matchesIncrementalPrefix(candidateToken, queryToken),
      );
      if (prefixIndex < 0) return const FoodSearchTextMatch();
      usedIncrementalPrefix = true;
      unmatched.removeAt(prefixIndex);
    }

    return FoodSearchTextMatch(
      tier: usedIncrementalPrefix
          ? FoodSearchTextMatchTier.wordPrefix
          : FoodSearchTextMatchTier.keywordOrContains,
      field: field,
      completesQueryTokens: !usedIncrementalPrefix,
      usesIncompleteTokenPrefix: usedIncrementalPrefix,
      closesIncompleteTokenPrefixes:
          !usedIncrementalPrefix && _hasSemanticQueryTokens(queryTokens),
    );
  }

  FoodSearchTextMatch _matchMetadataField(
    String candidate,
    String query,
    FoodSearchTextField field,
  ) {
    if (candidate.isEmpty) return const FoodSearchTextMatch();
    final candidateTokens = _tokens(candidate);
    final queryTokens = _tokens(query);
    if (candidateTokens.isEmpty || queryTokens.isEmpty) {
      return const FoodSearchTextMatch();
    }
    var usedIncrementalPrefix = false;
    final matches = queryTokens.every((queryToken) {
      if (candidateTokens.any(
        (candidateToken) => _matchesWholeToken(candidateToken, queryToken),
      )) {
        return true;
      }
      final prefixMatch = candidateTokens.any(
        (candidateToken) =>
            _matchesIncrementalPrefix(candidateToken, queryToken),
      );
      usedIncrementalPrefix = usedIncrementalPrefix || prefixMatch;
      return prefixMatch;
    });
    return matches
        ? FoodSearchTextMatch(
            tier: FoodSearchTextMatchTier.keywordOrContains,
            field: field,
            completesQueryTokens: !usedIncrementalPrefix,
            usesIncompleteTokenPrefix: usedIncrementalPrefix,
          )
        : const FoodSearchTextMatch();
  }

  bool _matchesPhrasePrefix(
    List<String> candidateTokens,
    List<String> queryTokens,
  ) {
    if (candidateTokens.length < queryTokens.length) return false;
    for (var index = 0; index < queryTokens.length; index++) {
      final candidate = candidateTokens[index];
      final query = queryTokens[index];
      final isLast = index == queryTokens.length - 1;
      if (_matchesWholeToken(candidate, query)) continue;
      if (isLast && _matchesIncrementalPrefix(candidate, query)) continue;
      return false;
    }
    return true;
  }

  bool _phraseUsesIncrementalPrefix(
    List<String> candidateTokens,
    List<String> queryTokens,
  ) {
    for (var index = 0; index < queryTokens.length; index++) {
      if (!_matchesWholeToken(candidateTokens[index], queryTokens[index])) {
        return true;
      }
    }
    return false;
  }

  bool _matchesWholeToken(String candidate, String query) =>
      candidate == query || candidate == '${query}s';

  bool _matchesIncrementalPrefix(String candidate, String query) {
    return candidate != query && candidate.startsWith(query);
  }

  bool _hasSemanticQueryTokens(List<String> queryTokens) =>
      queryTokens.every((token) => token.runes.length >= 3);

  List<String> _tokens(String value) => value
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);

  FoodSearchTextMatch _better(
    FoodSearchTextMatch current,
    FoodSearchTextMatch candidate,
  ) {
    if (candidate.rank != current.rank) {
      return candidate.rank > current.rank ? candidate : current;
    }
    if (candidate.completesQueryTokens != current.completesQueryTokens) {
      return candidate.completesQueryTokens ? candidate : current;
    }
    if (candidate.closesIncompleteTokenPrefixes !=
        current.closesIncompleteTokenPrefixes) {
      return candidate.closesIncompleteTokenPrefixes ? candidate : current;
    }
    return current;
  }
}
