class NoteMetrics {
  /// Calculates the word count of a given string.
  /// Standardized across the application for display footers and analytics.
  static int calculateWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}
