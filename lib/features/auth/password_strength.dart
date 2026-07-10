import 'package:flutter/material.dart';

import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

const int kNewPasswordMinLength = 8;

const _commonPasswords = <String>{
  'password',
  'password1',
  'password123',
  'qwerty',
  'qwerty123',
  'qwertyuiop',
  '123456',
  '1234567',
  '12345678',
  '123456789',
  '111111',
  '000000',
  'admin',
  'admin123',
  'letmein',
  'welcome',
  'iloveyou',
  'пароль',
  'пароль123',
  'йцукен',
};

class PasswordStrengthResult {
  const PasswordStrengthResult({
    required this.score,
    required this.isAcceptable,
    required this.labelRu,
    required this.labelEn,
    required this.hintsRu,
    required this.hintsEn,
  });

  final int score;
  final bool isAcceptable;
  final String labelRu;
  final String labelEn;
  final List<String> hintsRu;
  final List<String> hintsEn;

  double get progress => score.clamp(0, 4) / 4;

  String label(bool isRu) => isRu ? labelRu : labelEn;
  List<String> hints(bool isRu) => isRu ? hintsRu : hintsEn;
}

PasswordStrengthResult evaluatePasswordStrength(
  String password, {
  String? email,
  String? phone,
}) {
  final value = password.trim();
  final lower = value.toLowerCase();
  final hintsRu = <String>[];
  final hintsEn = <String>[];
  var score = 0;

  if (value.length >= kNewPasswordMinLength) {
    score += 1;
  } else {
    hintsRu.add('Минимум $kNewPasswordMinLength символов.');
    hintsEn.add('Use at least $kNewPasswordMinLength characters.');
  }

  final hasLetter = RegExp(r'[A-Za-zА-Яа-я]').hasMatch(value);
  final hasDigit = RegExp(r'\d').hasMatch(value);
  final hasSymbol = RegExp(r'[^A-Za-zА-Яа-я0-9]').hasMatch(value);
  final hasCaseMix =
      RegExp(r'[a-zа-я]').hasMatch(value) &&
      RegExp(r'[A-ZА-Я]').hasMatch(value);

  if (hasLetter && (hasDigit || hasSymbol)) {
    score += 1;
  } else {
    hintsRu.add('Добавьте буквы и цифры или символы.');
    hintsEn.add('Add letters and digits or symbols.');
  }

  if (value.length >= 10 || hasCaseMix || (hasDigit && hasSymbol)) {
    score += 1;
  } else {
    hintsRu.add('Лучше смешать регистр, цифры и спецсимволы.');
    hintsEn.add(
      'Mix case, digits and special characters for a stronger password.',
    );
  }

  final isCommon = _commonPasswords.contains(lower);
  final isRepeated = RegExp(r'^(.)\1+$').hasMatch(value);
  final isSequential = _looksSequential(lower);
  final containsIdentity = _containsIdentity(lower, email: email, phone: phone);

  if (!isCommon && !isRepeated && !isSequential && !containsIdentity) {
    score += 1;
  }

  if (isCommon) {
    hintsRu.add('Этот пароль слишком популярный.');
    hintsEn.add('This password is too common.');
  }
  if (isRepeated) {
    hintsRu.add('Не используйте один повторяющийся символ.');
    hintsEn.add('Do not use one repeated character.');
  }
  if (isSequential) {
    hintsRu.add('Не используйте простые последовательности.');
    hintsEn.add('Do not use simple sequences.');
  }
  if (containsIdentity) {
    hintsRu.add('Не используйте email, телефон или tag в пароле.');
    hintsEn.add('Do not include email, phone or tag in the password.');
  }

  final isAcceptable =
      score >= 3 &&
      value.length >= kNewPasswordMinLength &&
      !isCommon &&
      !isRepeated &&
      !isSequential &&
      !containsIdentity &&
      hasLetter &&
      (hasDigit || hasSymbol);

  final labelRu = score <= 1
      ? 'Слабый пароль'
      : score == 2
      ? 'Средний пароль'
      : score == 3
      ? 'Хороший пароль'
      : 'Сильный пароль';
  final labelEn = score <= 1
      ? 'Weak password'
      : score == 2
      ? 'Medium password'
      : score == 3
      ? 'Good password'
      : 'Strong password';

  return PasswordStrengthResult(
    score: score,
    isAcceptable: isAcceptable,
    labelRu: labelRu,
    labelEn: labelEn,
    hintsRu: hintsRu,
    hintsEn: hintsEn,
  );
}

String? newPasswordValidationMessage(
  String password, {
  required bool isRussian,
  String? email,
  String? phone,
}) {
  final result = evaluatePasswordStrength(password, email: email, phone: phone);
  if (result.isAcceptable) return null;
  final hints = result.hints(isRussian);
  if (hints.isEmpty) {
    return isRussian
        ? 'Пароль слишком простой.'
        : 'The password is too simple.';
  }
  return hints.join(' ');
}

bool _looksSequential(String value) {
  final normalized = value.replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
  if (normalized.length < 6) return false;
  const sequences = [
    'abcdefghijklmnopqrstuvwxyz',
    'zyxwvutsrqponmlkjihgfedcba',
    '0123456789',
    '9876543210',
    'qwertyuiopasdfghjklzxcvbnm',
    'йцукенгшщзхъфывапролджэячсмитьбю',
  ];
  return sequences.any((sequence) => sequence.contains(normalized));
}

bool _containsIdentity(String lower, {String? email, String? phone}) {
  final emailText = email?.trim().toLowerCase() ?? '';
  final localPart = emailText.split('@').first.trim();
  if (localPart.length >= 4 && lower.contains(localPart)) return true;

  final phoneDigits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (phoneDigits.length >= 6 && lower.contains(phoneDigits)) return true;
  return false;
}

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    super.key,
    required this.password,
    required this.isRussian,
    this.email,
    this.phone,
    this.compact = false,
  });

  final String password;
  final bool isRussian;
  final String? email;
  final String? phone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final result = evaluatePasswordStrength(
      password,
      email: email,
      phone: phone,
    );
    final color = result.isAcceptable
        ? kTextDark
        : result.score <= 1
        ? BrandTheme.redTop
        : kTextMuted;
    final hints = result.hints(isRussian);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: compact ? 5 : 6,
                  value: result.progress,
                  backgroundColor: Colors.black.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              result.label(isRussian),
              style: TextStyle(
                color: color,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (hints.isNotEmpty) ...[
          SizedBox(height: compact ? 6 : 8),
          Text(
            hints.take(2).join(' '),
            style: TextStyle(
              color: kTextMuted,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
              height: 1.22,
            ),
          ),
        ],
      ],
    );
  }
}
