import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/ui_constants.dart';

/// A feature is available to accounts with the Pro status.
///
/// On the web the dialog points to the plans page. In the mobile app nothing
/// is sold: the Pro status is granted by the PK Management team to the
/// agency's models and partners, so the dialog explains that and offers to
/// contact support (App Store 3.1.1 — no paywalls, no links to purchase).
Future<void> showProStatusRequiredDialog(BuildContext context) async {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  final t = AppLocalizations.of(context)!;
  final goTo = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Tokens.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      title: Text(
        kIsWeb
            ? t.billingUpgradeRequiredTitle
            : (ru ? 'Доступно со статусом Pro' : 'Available with Pro status'),
        style: AppText.h2,
      ),
      content: Text(
        kIsWeb
            ? t.billingUpgradeRequiredMessage
            : (ru
                  ? 'Чаты и приглашения открыты участникам со статусом Pro. Статус выдаёт администрация PK Management моделям и партнёрам агентства бесплатно — напишите нам через «Помощь и поддержка».'
                  : 'Chats and invitations are open to accounts with the Pro status. The status is granted free of charge by the PK Management team to the agency\'s models and partners — contact us via Help & support.'),
        style: AppText.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(ru ? 'Закрыть' : 'Close'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            kIsWeb
                ? (ru ? 'К тарифам' : 'Plans')
                : (ru ? 'В поддержку' : 'Contact support'),
          ),
        ),
      ],
    ),
  );
  if (goTo == true && context.mounted) {
    context.go(kIsWeb ? Routes.billing : Routes.support);
  }
}
