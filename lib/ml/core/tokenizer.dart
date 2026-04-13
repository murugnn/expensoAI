class Tokenizer {
  // Simple list of stop words to ignore
  static const Set<String> stopWords = {
    'the',
    'a',
    'an',
    'and',
    'or',
    'but',
    'in',
    'on',
    'at',
    'to',
    'for',
    'of',
    'with',
    'by',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'am',
    'i',
    'you',
    'he',
    'she',
    'it',
    'we',
    'they',
    'this',
    'that',
    'these',
    'those',
    'my',
    'your',
    'his',
    'her',
    'its',
    'our',
    'their',
    'from',
    'up',
    'down',
    'out',
    'over',
    'under',
    'again',
    'further',
    'then',
    'once',
    'here',
    'there',
    'when',
    'where',
    'why',
    'how',
    'all',
    'any',
    'both',
    'each',
    'few',
    'more',
    'most',
    'other',
    'some',
    'such',
    'no',
    'nor',
    'not',
    'only',
    'own',
    'same',
    'so',
    'than',
    'too',
    'very',
    's',
    't',
    'can',
    'will',
    'just',
    'don',
    'should',
    'now'
  };

  static List<String> tokenize(String text) {
    // 1. Lowercase
    String cleanText = text.toLowerCase();

    // 2. Remove special characters (keep only letters and numbers)
    cleanText = cleanText.replaceAll(RegExp(r'[^a-z0-9\s]'), '');

    // 3. Split by whitespace
    List<String> tokens = cleanText.split(RegExp(r'\s+'));

    // 4. Remove stop words and short words
    tokens.removeWhere((t) => t.length < 2 || stopWords.contains(t));

    return tokens;
  }
}
