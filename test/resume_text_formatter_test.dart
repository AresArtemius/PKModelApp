import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/core/resume_text_formatter.dart';

void main() {
  test('formats resume lists without changing their meaning', () {
    const source = '''
- показ одежды бренда "Никола Кидс" на форуме "Мамы.Дети.Бизнес"
-участие в шоу "ЛПшки"
-участие в передаче "Время Первых"
-съемка рекламных рилс Term Gremm
-съемка рекламных рилс для ЦДМ на Лубянке
-съемка в каталоге бренда "PlayToday"
''';

    expect(formatResumeText(source), '''
— показ одежды бренда «Никола Кидс» на форуме «Мамы. Дети. Бизнес»
— участие в шоу «ЛПшки»
— участие в передаче «Время Первых»
— съёмка рекламных рилс Term Gremm
— съёмка рекламных рилс для ЦДМ на Лубянке
— съёмка в каталоге бренда «PlayToday»''');
  });

  test('keeps paragraphs and collapses excessive blank lines', () {
    const source =
        '  Опыт работы 5 лет.Работаю в Москве. \n\n\n Портфолио по ссылке. ';

    expect(
      formatResumeText(source),
      'Опыт работы 5 лет. Работаю в Москве.\n\nПортфолио по ссылке.',
    );
  });
}
