/// Smart multi-field search and alphabetical priority ranking engine.
class SmartSearchEngine {
  SmartSearchEngine._();

  /// Filters and sorts [items] based on [query].
  ///
  /// - When [query] is empty, items are sorted by [fallbackComparator] if provided,
  ///   or alphabetically (A → Z) by [primaryTextBuilder] (ignoring leading titles like "Dr. ").
  /// - When [query] is non-empty, items are matched across [primaryTextBuilder] and
  ///   all [secondaryTextsBuilder] fields, then ranked into 3 priority tiers:
  ///   1. Tier 1: Primary name starts with [query] (or stripped name starts with [query]), sorted A → Z.
  ///   2. Tier 2: Primary name contains [query] anywhere, sorted A → Z.
  ///   3. Tier 3: Any secondary attribute (specialty, category ID, bio, email, blood group, ID, etc.)
  ///      contains [query], sorted A → Z by primary name.
  static List<T> filterAndSort<T>({
    required List<T> items,
    required String query,
    required String Function(T item) primaryTextBuilder,
    required List<String?> Function(T item) secondaryTextsBuilder,
    int Function(T a, T b)? fallbackComparator,
  }) {
    final trimmedQuery = query.trim().toLowerCase();

    int compareAlphabetically(T a, T b) {
      final nameA = _normalizeName(primaryTextBuilder(a));
      final nameB = _normalizeName(primaryTextBuilder(b));
      final cmp = nameA.compareTo(nameB);
      if (cmp != 0) return cmp;
      return primaryTextBuilder(a)
          .toLowerCase()
          .compareTo(primaryTextBuilder(b).toLowerCase());
    }

    if (trimmedQuery.isEmpty) {
      final copy = List<T>.from(items);
      copy.sort(fallbackComparator ?? compareAlphabetically);
      return copy;
    }

    final tier1 = <T>[];
    final tier2 = <T>[];
    final tier3 = <T>[];

    for (final item in items) {
      final rawPrimary = primaryTextBuilder(item).trim().toLowerCase();
      final normalizedPrimary = _normalizeName(rawPrimary);

      if (rawPrimary.startsWith(trimmedQuery) ||
          normalizedPrimary.startsWith(trimmedQuery)) {
        tier1.add(item);
        continue;
      }

      if (rawPrimary.contains(trimmedQuery) ||
          normalizedPrimary.contains(trimmedQuery)) {
        tier2.add(item);
        continue;
      }

      final secondaryFields = secondaryTextsBuilder(item);
      bool matchedSecondary = false;
      for (final field in secondaryFields) {
        if (field != null && field.toLowerCase().contains(trimmedQuery)) {
          matchedSecondary = true;
          break;
        }
      }

      if (matchedSecondary) {
        tier3.add(item);
      }
    }

    tier1.sort(compareAlphabetically);
    tier2.sort(compareAlphabetically);
    tier3.sort(compareAlphabetically);

    return [...tier1, ...tier2, ...tier3];
  }

  /// Strips common honorific prefixes ("dr.", "dr ") so "Dr. Emily" sorts under "e" or matches "emily" prefix.
  static String _normalizeName(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.startsWith('dr. ')) {
      return lower.substring(4).trim();
    }
    if (lower.startsWith('dr ')) {
      return lower.substring(3).trim();
    }
    return lower;
  }
}

