class ContentSafetyIssue {
  const ContentSafetyIssue({required this.fieldLabel});

  final String fieldLabel;
}

abstract final class ContentSafetyFilter {
  static final RegExp _splitter = RegExp(r'[^0-9a-zA-Zа-яА-ЯёЁ]+');
  static final List<RegExp> _blockedTokenPatterns = <RegExp>[
    RegExp(r'^х[уy][йеияю].*'),
    RegExp(r'^п[иеe]зд.*'),
    RegExp(r'^бл[яьа].*'),
    RegExp(r'^(за|вы|у|по|на|от)?е[б6][аеиоуы].*'),
    RegExp(r'^(за|вы|у|по|на|от)?е[б6]л.*'),
    RegExp(r'^муд[ао]к.*'),
    RegExp(r'^пид[оа]р.*'),
    RegExp(r'^залуп.*'),
    RegExp(r'^шлюх.*'),
    RegExp(r'^проститут.*'),
    RegExp(r'^порно.*'),
    RegExp(r'^porn.*'),
    RegExp(r'^nude.*'),
    RegExp(r'^fuck.*'),
    RegExp(r'^dick.*'),
    RegExp(r'^pussy.*'),
  ];

  static ContentSafetyIssue? firstIssue(Map<String, String> fields) {
    for (final entry in fields.entries) {
      if (hasBlockedText(entry.value)) {
        return ContentSafetyIssue(fieldLabel: entry.key);
      }
    }
    return null;
  }

  static bool hasBlockedText(String text) {
    final normalized = text.toLowerCase().replaceAll('ё', 'е');
    final tokens = normalized
        .split(_splitter)
        .where((token) => token.trim().isNotEmpty);
    for (final token in tokens) {
      for (final pattern in _blockedTokenPatterns) {
        if (pattern.hasMatch(token)) return true;
      }
    }
    return false;
  }

  static String message({required bool isRussian, required String fieldLabel}) {
    if (isRussian) {
      return 'Поле «$fieldLabel» содержит непристойный текст. Измените формулировку, чтобы продолжить.';
    }
    return 'The $fieldLabel field contains inappropriate text. Please rephrase it to continue.';
  }
}
