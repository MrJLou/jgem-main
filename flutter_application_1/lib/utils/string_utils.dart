/// Utility functions for string manipulation
class StringUtils {
  /// Safely truncate a string to a maximum length
  /// Returns the original string if it's shorter than maxLength
  /// Returns a truncated string with optional suffix if longer
  static String safeTruncate(String? input, int maxLength,
      {String suffix = '...'}) {
    if (input == null || input.isEmpty) return 'N/A';
    if (input.length <= maxLength) return input;
    return '${input.substring(0, maxLength)}$suffix';
  }

  /// Safely get substring without throwing RangeError
  /// Returns the original string if it's shorter than the requested length
  static String safeSubstring(String? input, int start, int? end) {
    if (input == null || input.isEmpty) return 'N/A';
    if (start >= input.length) return 'N/A';

    final actualEnd =
        end != null ? (end > input.length ? input.length : end) : input.length;

    return input.substring(start, actualEnd);
  }

  /// Get first N characters safely
  static String firstNChars(String? input, int n) {
    return safeSubstring(input, 0, n);
  }

  /// Get last N characters safely
  static String lastNChars(String? input, int n) {
    if (input == null || input.isEmpty) return 'N/A';
    if (input.length <= n) return input;
    return input.substring(input.length - n);
  }

  /// Format ID for display (first 8 characters with ...)
  static String formatIdForDisplay(String? id) {
    return safeTruncate(id, 8, suffix: '...');
  }

  /// Generate short reference from UUID (first 8 characters, uppercase)
  static String generateShortReference(String uuid, {String prefix = ''}) {
    final cleanUuid = uuid.replaceAll('-', '');
    final shortRef = firstNChars(cleanUuid, 8).toUpperCase();
    return prefix.isEmpty ? shortRef : '$prefix$shortRef';
  }
}
