import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/features/legal/legal_documents.dart';

void main() {
  group('child safety standards', () {
    final document = legalDocumentByKind(LegalDocumentKind.childSafety);

    test('uses the public Play Console route and its own version', () {
      expect(document.route, '/child-safety');
      expect(document.version, kChildSafetyStandardsVersion);
    });

    test('explicitly names the app, CSAE, CSAM, reporting and contact', () {
      final russianText = document.sectionsRu
          .map((section) => '${section.title} ${section.body}')
          .join(' ');
      final englishText = document.sectionsEn
          .map((section) => '${section.title} ${section.body}')
          .join(' ');

      for (final requiredText in [
        'PK Management',
        'CSAE',
        'CSAM',
        'artem@president-kids.ru',
      ]) {
        expect(russianText, contains(requiredText));
        expect(englishText, contains(requiredText));
      }

      expect(russianText, contains('Помощь и поддержка'));
      expect(englishText, contains('Help & support'));
    });
  });
}
