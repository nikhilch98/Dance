/// String extension utilities for the Nachna app.
///
/// This extension provides common string manipulation methods used across the app.
extension StringExtensions on String {
  /// Converts a string to title case (first letter of each word capitalized).
  ///
  /// Example:
  /// ```dart
  /// 'hello world'.toTitleCase() // Returns 'Hello World'
  /// 'JOHN DOE'.toTitleCase() // Returns 'John Doe'
  /// ```
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
