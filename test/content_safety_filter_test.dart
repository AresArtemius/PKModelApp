import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/core/content_safety_filter.dart';

void main() {
  group('ContentSafetyFilter', () {
    test('blocks inappropriate Russian and English text', () {
      expect(ContentSafetyFilter.hasBlockedText('Это порно-контент'), isTrue);
      expect(ContentSafetyFilter.hasBlockedText('fuck this'), isTrue);
    });

    test('blocks words next to punctuation and in mixed case', () {
      expect(ContentSafetyFilter.hasBlockedText('ПОРНО!'), isTrue);
      expect(ContentSafetyFilter.hasBlockedText('(nude), photo'), isTrue);
    });

    test('allows normal profile and chat copy', () {
      const safeTexts = <String>[
        'Модель, 18 лет. Опыт съёмок для каталогов и рекламы.',
        'Портретная и fashion-съёмка, Москва и Санкт-Петербург.',
        'Здравствуйте! Приглашаем вас на кастинг в пятницу.',
        'Работаю с нюдовым макияжем и естественным светом.',
      ];

      for (final text in safeTexts) {
        expect(
          ContentSafetyFilter.hasBlockedText(text),
          isFalse,
          reason: 'Нормальный текст не должен блокироваться: $text',
        );
      }
    });

    test('returns the first field containing blocked text', () {
      final issue = ContentSafetyFilter.firstIssue({
        'имя': 'Анна',
        'резюме': 'Порно-контент',
        'опыт': 'Реклама и каталоги',
      });

      expect(issue?.fieldLabel, 'резюме');
    });

    test('builds localized user-facing messages', () {
      expect(
        ContentSafetyFilter.message(isRussian: true, fieldLabel: 'сообщение'),
        contains('Поле «сообщение»'),
      );
      expect(
        ContentSafetyFilter.message(isRussian: false, fieldLabel: 'message'),
        contains('The message field'),
      );
    });
  });
}
