import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

class AccountDeletionPage extends StatelessWidget {
  const AccountDeletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final sections = isRu ? _sectionsRu : _sectionsEn;

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Row(
                  children: [
                    _BackButton(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(Routes.login);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isRu ? 'УДАЛЕНИЕ АККАУНТА' : 'ACCOUNT DELETION',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: BrandTheme.pillText.copyWith(
                          color: kTextDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 60),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kCardRadius),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFFFFF), Color(0xFFF2F2F2)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                    boxShadow: BrandTheme.surfaceShadow(
                      darkColor: Colors.black.withValues(alpha: 0.18),
                      darkBlur: 28,
                      darkOffset: const Offset(0, 14),
                      lightColor: Colors.white.withValues(alpha: 0.72),
                      lightBlur: 18,
                      lightOffset: const Offset(0, -8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu
                            ? 'PK Management · ООО «Модельное агентство “Биг Вест”»'
                            : 'PK Management · Model Agency Big West LLC',
                        style: _bodyStyle(
                          color: kTextMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final section in sections) ...[
                        Text(section.title, style: _titleStyle()),
                        const SizedBox(height: 8),
                        SelectableText(section.body, style: _bodyStyle()),
                        const SizedBox(height: 18),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle _titleStyle() {
    return BrandTheme.pillText.copyWith(
      color: kTextDark,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      height: 1.2,
    );
  }

  static TextStyle _bodyStyle({
    Color color = kTextDark,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return TextStyle(
      color: color,
      fontSize: 15,
      fontWeight: fontWeight,
      height: 1.45,
    );
  }
}

class _DeletionSection {
  const _DeletionSection(this.title, this.body);

  final String title;
  final String body;
}

const _sectionsRu = <_DeletionSection>[
  _DeletionSection(
    'Как удалить аккаунт в приложении',
    '1. Войдите в PK Management.\n'
        '2. Откройте раздел «Мой аккаунт».\n'
        '3. Прокрутите страницу вниз и нажмите «Удалить аккаунт».\n'
        '4. Ознакомьтесь с предупреждением и подтвердите удаление.\n\n'
        'После подтверждения аккаунт удаляется из активной базы, выполняется выход из приложения, а публичные анкеты перестают быть доступны.',
  ),
  _DeletionSection(
    'Как отправить запрос без входа в приложение',
    'Напишите на info@president-kids.ru с адреса электронной почты, связанного с аккаунтом. Укажите тему «Удаление аккаунта PK Management», email или телефон аккаунта и явно попросите удалить аккаунт. Для защиты данных мы можем запросить подтверждение личности. Запрос будет обработан в срок до 30 дней.',
  ),
  _DeletionSection(
    'Какие данные удаляются',
    'Удаляются учетная запись, профиль аккаунта, профессиональные анкеты, роли, настройки и токены уведомлений, пользовательские уведомления, отклики, подборки и созданные пользователем рабочие данные, а также связанные сообщения и доступные приложению материалы — в объеме, позволяющем идентифицировать владельца аккаунта.',
  ),
  _DeletionSection(
    'Удаление отдельных данных без удаления аккаунта',
    'Чтобы удалить отдельную анкету, фото или другой материал, используйте соответствующую кнопку удаления в приложении. Также можно направить запрос через раздел «Мой аккаунт» → «Помощь и поддержка» или на info@president-kids.ru, указав, какие именно данные нужно удалить.',
  ),
  _DeletionSection(
    'Какие данные могут сохраняться',
    'Отдельные платежные, бухгалтерские, юридические, антифрод-записи, подтверждения согласий и журналы безопасности могут храниться только в объеме и в течение срока, необходимого для исполнения требований законодательства, разрешения споров и защиты сервиса. После истечения обязательного срока такие записи удаляются или обезличиваются. Технические резервные копии могут обновляться не мгновенно и очищаются в рамках стандартного цикла хранения инфраструктуры.',
  ),
];

const _sectionsEn = <_DeletionSection>[
  _DeletionSection(
    'Delete your account in the app',
    '1. Sign in to PK Management.\n'
        '2. Open “My account”.\n'
        '3. Scroll down and tap “Delete account”.\n'
        '4. Review the warning and confirm deletion.\n\n'
        'After confirmation, the account is removed from the active database, the user is signed out, and public profiles are no longer available.',
  ),
  _DeletionSection(
    'Request deletion without signing in',
    'Email info@president-kids.ru from the address associated with the account. Use the subject “PK Management account deletion”, include the account email or phone number, and clearly request account deletion. We may ask for identity verification to protect your data. Requests are processed within 30 days.',
  ),
  _DeletionSection(
    'Data that is deleted',
    'We delete the user account, account profile, professional profiles, roles, notification settings and tokens, user notifications, applications, selections and user-created workflow data, as well as related messages and materials available to the app to the extent they identify the account owner.',
  ),
  _DeletionSection(
    'Delete selected data without deleting the account',
    'Use the relevant delete action in the app to remove an individual profile, photo or other material. You may also submit a request through “My account” → “Help & support” or email info@president-kids.ru and specify the data you want removed.',
  ),
  _DeletionSection(
    'Data that may be retained',
    'Limited payment, accounting, legal, anti-fraud, consent and security records may be retained only to the extent and for the period required by applicable law, dispute resolution and service protection. Those records are deleted or anonymized after the mandatory period. Technical backups may not update immediately and are cleared according to the infrastructure retention cycle.',
  ),
];

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: BrandTheme.lightPillGradient,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: kTextDark,
          size: 22,
        ),
      ),
    );
  }
}
