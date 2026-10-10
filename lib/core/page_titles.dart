import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';

const int _kTitleColor = 0xFF020202;
const String _kAppTitle = 'PK Management';

/// Keeps the browser tab title in sync with the current route on web.
///
/// Pages that know a better title (a model's name, a casting title) wrap
/// their content in [Title]; the next navigation resets it to the route's
/// own title.
class PageTitleSync {
  PageTitleSync(this._router, this._isRussian) {
    if (!kIsWeb) return;
    _router.routerDelegate.addListener(_update);
    _update();
  }

  final GoRouter _router;
  final bool Function() _isRussian;

  void dispose() {
    if (!kIsWeb) return;
    _router.routerDelegate.removeListener(_update);
  }

  void _update() {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    final section = titleForPath(path, russian: _isRussian());
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: section == null ? _kAppTitle : '$section — $_kAppTitle',
        primaryColor: _kTitleColor,
      ),
    );
  }
}

/// Section title for a route path, or null for the bare app title.
String? titleForPath(String path, {required bool russian}) {
  String pick(String ru, String en) => russian ? ru : en;
  if (path == Routes.search) return pick('Каталог', 'Catalog');
  if (path == Routes.castings) return pick('Кастинги', 'Castings');
  if (path == Routes.chats || path.startsWith(Routes.chatsChatPrefix)) {
    return pick('Чаты', 'Chats');
  }
  if (path.startsWith(Routes.chatPrefix)) return pick('Чат', 'Chat');
  if (path == Routes.invitations) return pick('Приглашения', 'Invitations');
  if (path == Routes.me) return pick('Мой аккаунт', 'My account');
  if (path == Routes.login) return pick('Вход', 'Sign in');
  if (path == Routes.register) return pick('Регистрация', 'Sign up');
  if (path == Routes.emailVerification) {
    return pick('Подтверждение email', 'Email verification');
  }
  if (path == Routes.onboarding) return pick('Начало работы', 'Getting started');
  if (path == Routes.billing) return pick('Тарифы', 'Plans');
  if (path == Routes.notifications) return pick('Уведомления', 'Notifications');
  if (path == Routes.profileAnalytics) return pick('Аналитика', 'Analytics');
  if (path == Routes.following) return pick('Подписки', 'Follows');
  if (path == Routes.feed) return pick('Лента', 'Feed');
  if (path == Routes.support) return pick('Помощь и поддержка', 'Help & support');
  if (path == Routes.accountProfile) {
    return pick('Профиль аккаунта', 'Account profile');
  }
  if (path == Routes.accountMfa) return pick('Безопасность', 'Security');
  if (path == Routes.accountDevices) return pick('Устройства', 'Devices');
  if (path == Routes.dataPrivacy) return pick('Данные и удаление', 'Data & deletion');
  if (path == Routes.agentFolders) return pick('Папки', 'Folders');
  if (path.startsWith(Routes.modelPrefix) || path.startsWith(Routes.publicModelPrefix)) {
    return pick('Анкета', 'Profile');
  }
  if (path.startsWith(Routes.publicSelectionPrefix)) {
    return pick('Подборка', 'Selection');
  }
  if (path.startsWith(Routes.publicAccountPrefix)) {
    return pick('Аккаунт', 'Account');
  }
  if (path == Routes.privacyPolicy) return pick('Конфиденциальность', 'Privacy');
  if (path == Routes.termsOfService) return pick('Условия', 'Terms');
  if (path == Routes.childSafety) {
    return pick('Безопасность детей', 'Child safety');
  }
  if (path == Routes.cookiePolicy) return pick('Cookies', 'Cookies');
  if (path == Routes.requisites) return pick('Реквизиты', 'Requisites');
  if (path.contains('admin') || path == Routes.safetyAdmin) {
    return pick('Админ-панель', 'Admin');
  }
  return null;
}

/// Wraps [child] so the browser tab shows [title] while it is on screen.
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final trimmed = title.trim();
    return Title(
      title: trimmed.isEmpty ? _kAppTitle : '$trimmed — $_kAppTitle',
      color: const Color(_kTitleColor),
      child: child,
    );
  }
}
