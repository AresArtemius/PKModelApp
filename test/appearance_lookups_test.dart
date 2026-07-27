import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/ui/brand/appearance_lookups.dart';

void main() {
  test('appearance options are localized without changing stored values', () {
    expect(eyeColorOptions(const Locale('ru')).first, 'Карий');
    expect(eyeColorOptions(const Locale('en')).first, 'Brown');
    expect(hairColorOptions(const Locale('en')).first, 'Light blonde');

    expect(eyeColorDisplayValue('Карий', const Locale('en')), 'Brown');
    expect(
      hairColorDisplayValue('Светлый блонд', const Locale('en')),
      'Light blonde',
    );
    expect(eyeColorStorageValue('Brown'), 'Карий');
    expect(hairColorStorageValue('Light blonde'), 'Светлый блонд');
  });

  test('appearance conversion preserves unknown legacy values', () {
    expect(
      eyeColorDisplayValue('Редкий оттенок', const Locale('en')),
      'Редкий оттенок',
    );
    expect(hairColorStorageValue('Custom shade'), 'Custom shade');
  });
}
