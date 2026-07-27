import 'package:flutter/widgets.dart';

class _AppearanceOption {
  const _AppearanceOption({
    required this.storageValue,
    required this.englishValue,
  });

  final String storageValue;
  final String englishValue;
}

const _eyeColors = <_AppearanceOption>[
  _AppearanceOption(storageValue: 'Карий', englishValue: 'Brown'),
  _AppearanceOption(storageValue: 'Светло-карий', englishValue: 'Light brown'),
  _AppearanceOption(storageValue: 'Тёмно-карий', englishValue: 'Dark brown'),
  _AppearanceOption(storageValue: 'Голубой', englishValue: 'Blue'),
  _AppearanceOption(storageValue: 'Серо-голубой', englishValue: 'Blue-grey'),
  _AppearanceOption(storageValue: 'Зелёный', englishValue: 'Green'),
  _AppearanceOption(storageValue: 'Серо-зелёный', englishValue: 'Grey-green'),
  _AppearanceOption(storageValue: 'Серый', englishValue: 'Grey'),
  _AppearanceOption(storageValue: 'Ореховый', englishValue: 'Hazel'),
  _AppearanceOption(storageValue: 'Янтарный', englishValue: 'Amber'),
  _AppearanceOption(storageValue: 'Чёрный', englishValue: 'Black'),
];

const _hairColors = <_AppearanceOption>[
  _AppearanceOption(
    storageValue: 'Светлый блонд',
    englishValue: 'Light blonde',
  ),
  _AppearanceOption(
    storageValue: 'Пепельный блонд',
    englishValue: 'Ash blonde',
  ),
  _AppearanceOption(storageValue: 'Тёмный блонд', englishValue: 'Dark blonde'),
  _AppearanceOption(storageValue: 'Светло-русый', englishValue: 'Light brown'),
  _AppearanceOption(storageValue: 'Русый', englishValue: 'Brown'),
  _AppearanceOption(storageValue: 'Тёмно-русый', englishValue: 'Dark brown'),
  _AppearanceOption(
    storageValue: 'Светло-каштановый',
    englishValue: 'Light chestnut',
  ),
  _AppearanceOption(storageValue: 'Каштановый', englishValue: 'Chestnut'),
  _AppearanceOption(
    storageValue: 'Тёмно-каштановый',
    englishValue: 'Dark chestnut',
  ),
  _AppearanceOption(storageValue: 'Брюнет', englishValue: 'Brunette'),
  _AppearanceOption(storageValue: 'Чёрный', englishValue: 'Black'),
  _AppearanceOption(storageValue: 'Рыжий', englishValue: 'Red'),
  _AppearanceOption(storageValue: 'Медный', englishValue: 'Copper'),
  _AppearanceOption(storageValue: 'Золотистый', englishValue: 'Golden'),
  _AppearanceOption(storageValue: 'Пепельный', englishValue: 'Ash'),
  _AppearanceOption(storageValue: 'Седой', englishValue: 'Grey'),
];

bool _isRussian(Locale locale) =>
    locale.languageCode.toLowerCase().startsWith('ru');

String _normalized(String value) => value.trim().toLowerCase();

List<String> _localizedOptions(List<_AppearanceOption> options, Locale locale) {
  final russian = _isRussian(locale);
  return options
      .map((option) => russian ? option.storageValue : option.englishValue)
      .toList(growable: false);
}

String _displayValue(
  List<_AppearanceOption> options,
  String value,
  Locale locale,
) {
  final normalized = _normalized(value);
  if (normalized.isEmpty) return '';
  final russian = _isRussian(locale);
  for (final option in options) {
    if (_normalized(option.storageValue) == normalized ||
        _normalized(option.englishValue) == normalized) {
      return russian ? option.storageValue : option.englishValue;
    }
  }
  return value.trim();
}

String _storageValue(List<_AppearanceOption> options, String value) {
  final normalized = _normalized(value);
  if (normalized.isEmpty) return '';
  for (final option in options) {
    if (_normalized(option.storageValue) == normalized ||
        _normalized(option.englishValue) == normalized) {
      return option.storageValue;
    }
  }
  return value.trim();
}

List<String> eyeColorOptions(Locale locale) =>
    _localizedOptions(_eyeColors, locale);

List<String> hairColorOptions(Locale locale) =>
    _localizedOptions(_hairColors, locale);

String eyeColorDisplayValue(String value, Locale locale) =>
    _displayValue(_eyeColors, value, locale);

String hairColorDisplayValue(String value, Locale locale) =>
    _displayValue(_hairColors, value, locale);

String eyeColorStorageValue(String value) => _storageValue(_eyeColors, value);

String hairColorStorageValue(String value) => _storageValue(_hairColors, value);
