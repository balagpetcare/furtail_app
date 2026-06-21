
class ProfanityFilter {
  static const _badWords = [
    // English
    'fuck','shit','bitch',
    // Bangla
    'চোদ','চুদি','মাগী',
    // Banglish
    'chod','chudi','magi',
  ];

  static String clean(String input) {
    var out = input;
    for (final w in _badWords) {
      out = out.replaceAll(RegExp(w, caseSensitive: false), '***');
    }
    return out;
  }
}
