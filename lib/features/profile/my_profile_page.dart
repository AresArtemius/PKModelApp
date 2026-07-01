import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account_deletion_service.dart';
import '../../core/account_profile_service.dart';
import '../../core/app_error_mapper.dart';
import '../../core/auth_providers.dart';
import '../../core/entitlements_provider.dart';
import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'account_profile_edit_page.dart';
import 'my_profile_controller.dart';
import 'my_profile_edit_page.dart';
import 'profile_media_upload_queue.dart';
import 'profile_model.dart';
import 'profile_type_selection_page.dart';

const EdgeInsets _kProfileCardPad = kLoginCardPad;
const double _kAccountLogoutButtonWidth = 112.0;
const double _kAccountDesktopBreakpoint = 900.0;
const double _kAccountDesktopMaxWidth = 1360.0;
const EdgeInsets _kAccountDesktopPad = EdgeInsets.fromLTRB(32, 28, 32, 32);

TextStyle _accountCommandStyle({
  Color color = kTextDark,
  double size = 16,
  double spacing = 1.6,
  FontWeight weight = FontWeight.w600,
}) {
  return BrandTheme.pillText.copyWith(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
  );
}

TextStyle _accountBodyStyle({
  Color color = kTextMuted,
  double size = 15,
  double spacing = 0.2,
  FontWeight weight = FontWeight.w500,
  double height = 1.18,
}) {
  return TextStyle(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
    height: height,
  );
}

String _accountLocaleText(BuildContext context, String ru, String en) {
  return Localizations.localeOf(context).languageCode.toLowerCase() == 'ru'
      ? ru
      : en;
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: kProfileErrorPad,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: _accountBodyStyle(
            color: kTextDanger,
            weight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class MyProfilePage extends ConsumerWidget {
  const MyProfilePage({super.key});

  void _openEditor(
    BuildContext context, {
    required bool startBlank,
    MyProfileState? initial,
    ProfessionalProfileType? initialProfileType,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyProfileEditPage(
          startBlank: startBlank,
          initial: initial,
          initialProfileType: initialProfileType,
        ),
      ),
    );
  }

  Future<void> _openTypeSelector(BuildContext context) async {
    final selected = await Navigator.of(context).push<ProfessionalProfileType>(
      MaterialPageRoute(builder: (_) => const ProfileTypeSelectionPage()),
    );
    if (!context.mounted || selected == null) return;
    _openEditor(
      context,
      startBlank: true,
      initial: null,
      initialProfileType: selected,
    );
  }

  List<Widget> _accountTools(BuildContext context) {
    return [
      _BillingEntryCard(onTap: () => context.go(Routes.billing)),
      const SizedBox(height: kGap14),
      _AccountEntryCard(
        icon: Icons.notifications_rounded,
        title: AppLocalizations.of(context)!.notificationsUpper,
        subtitle: AppLocalizations.of(
          context,
        )!.notificationsAccountEntrySubtitle,
        onTap: () => context.go(Routes.notifications),
      ),
      const SizedBox(height: kGap14),
      _AccountEntryCard(
        icon: Icons.analytics_rounded,
        title: AppLocalizations.of(context)!.analyticsUpper,
        subtitle: AppLocalizations.of(context)!.analyticsAccountEntrySubtitle,
        onTap: () => context.go(Routes.profileAnalytics),
      ),
      const SizedBox(height: kGap14),
      const _OwnerProfileEntryCard(),
      const SizedBox(height: kGap14),
      const _AccountStatusEntryCard(),
      const SizedBox(height: kGap14),
      const _DeleteAccountEntryCard(),
    ];
  }

  List<Widget> _profileCards(
    BuildContext context,
    List<MyProfileState> profiles,
    List<ProfileMediaUploadTask> uploads,
    WidgetRef ref,
  ) {
    ProfileMediaUploadTask? latestUpload(String profileId) {
      for (final task in uploads.reversed) {
        if (task.profileId == profileId) return task;
      }
      return null;
    }

    return [
      for (final p in profiles)
        Padding(
          padding: const EdgeInsets.only(bottom: kProfileItemBottomGap),
          child: _ProfileSummaryCard(
            fullName: p.fullName.trim(),
            status: p.status,
            photoUrl: p.effectiveCoverPhotoUrl.isEmpty
                ? null
                : p.effectiveCoverPhotoUrl,
            uploadTask: latestUpload(p.id),
            onRetryUpload: (task) => ref
                .read(profileMediaUploadQueueProvider.notifier)
                .retry(task.id),
            onDismissUpload: (task) => ref
                .read(profileMediaUploadQueueProvider.notifier)
                .dismiss(task.id),
            onTap: () => _openEditor(context, startBlank: false, initial: p),
          ),
        ),
    ];
  }

  Widget _mobileLayout(
    BuildContext context,
    List<MyProfileState> profiles,
    Future<void> Function() logout,
    AppLocalizations t,
    WidgetRef ref,
  ) {
    final uploads = ref.watch(profileMediaUploadQueueProvider);
    return ListView(
      padding: kMyProfilePagePad,
      children: [
        _AddProfileAction(
          label: profiles.isEmpty ? t.profileCreateUpper : t.addProfileUpper,
          onTap: () => _openTypeSelector(context),
          onLogout: logout,
          logoutLabel: t.logoutUpper,
        ),
        const SizedBox(height: kGap14),
        ..._profileCards(context, profiles, uploads, ref),
        if (profiles.isNotEmpty) const SizedBox(height: kGap14),
        ..._accountTools(context),
      ],
    );
  }

  Widget _desktopLayout(
    BuildContext context,
    List<MyProfileState> profiles,
    Future<void> Function() logout,
    AppLocalizations t,
    WidgetRef ref,
  ) {
    final uploads = ref.watch(profileMediaUploadQueueProvider);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kAccountDesktopMaxWidth),
        child: ListView(
          padding: _kAccountDesktopPad,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DesktopSectionTitle(
                        title: _accountLocaleText(
                          context,
                          'МОИ АНКЕТЫ',
                          'MY PROFILES',
                        ),
                        subtitle: profiles.isEmpty
                            ? t.profileCreateUpper
                            : t.addProfileUpper,
                      ),
                      const SizedBox(height: 14),
                      _AddProfileAction(
                        label: profiles.isEmpty
                            ? t.profileCreateUpper
                            : t.addProfileUpper,
                        onTap: () => _openTypeSelector(context),
                        onLogout: logout,
                        logoutLabel: t.logoutUpper,
                      ),
                      const SizedBox(height: kGap14),
                      if (profiles.isEmpty)
                        _DesktopEmptyProfilesCard(
                          title: t.profileCreateUpper,
                          onTap: () => _openTypeSelector(context),
                        )
                      else
                        ..._profileCards(context, profiles, uploads, ref),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DesktopSectionTitle(
                        title: t.accountUpper,
                        subtitle: _accountLocaleText(
                          context,
                          'Тарифы, уведомления, аналитика и статус',
                          'Billing, notifications, analytics, and status',
                        ),
                      ),
                      const SizedBox(height: 14),
                      ..._accountTools(context),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myProfileProvider);
    final t = AppLocalizations.of(context)!;

    Future<void> logout() async {
      final sb = ref.read(supabaseProvider);
      context.go(Routes.login);
      await sb.auth.signOut();
    }

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: async.when(
              loading: () => const _LoadingView(),
              error: (e, _) => _ErrorView(
                message: t.profileLoadError(AppErrorMapper.message(e, t)),
              ),
              data: (profiles) {
                final isDesktop =
                    MediaQuery.sizeOf(context).width >=
                    _kAccountDesktopBreakpoint;
                return isDesktop
                    ? _desktopLayout(context, profiles, logout, t, ref)
                    : _mobileLayout(context, profiles, logout, t, ref);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerProfileEntryCard extends ConsumerWidget {
  const _OwnerProfileEntryCard();

  bool _isRussian(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AccountProfileEditPage()),
    );
    if (saved == true) {
      ref.invalidate(accountOwnerProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = _isRussian(context);
    final user = ref.watch(currentUserProvider);
    final needsEmail =
        (user?.phone?.trim().isNotEmpty ?? false) &&
        (user?.email?.trim().isEmpty ?? true);
    final profileAsync = ref.watch(accountOwnerProfileProvider);
    final avatarUrl = profileAsync.maybeWhen(
      data: (profile) => profile.avatarUrl,
      orElse: () => '',
    );
    final subtitle = profileAsync.maybeWhen(
      data: (profile) {
        if (needsEmail) {
          return ru
              ? 'Добавьте email для восстановления доступа'
              : 'Add email for account recovery';
        }
        final name = profile.displayName;
        if (name.isNotEmpty) return name;
        return ru
            ? 'Ваши данные, контакты и организация'
            : 'Your details, contacts, and organization';
      },
      orElse: () => ru
          ? 'Ваши данные, контакты и организация'
          : 'Your details, contacts, and organization',
    );

    return _AccountEntryCard(
      icon: Icons.assignment_ind_rounded,
      avatarUrl: avatarUrl,
      title: ru ? 'ПРОФИЛЬ АККАУНТА' : 'ACCOUNT PROFILE',
      subtitle: subtitle,
      onTap: () => _open(context, ref),
    );
  }
}

class _AccountStatusEntryCard extends ConsumerStatefulWidget {
  const _AccountStatusEntryCard();

  @override
  ConsumerState<_AccountStatusEntryCard> createState() =>
      _AccountStatusEntryCardState();
}

class _AccountStatusEntryCardState
    extends ConsumerState<_AccountStatusEntryCard> {
  bool _saving = false;
  final Set<String> _shownRejectedDialogs = <String>{};

  bool get _isRussian {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
  }

  String _title() => _isRussian ? 'СТАТУС АККАУНТА' : 'ACCOUNT STATUS';

  String _subtitle(AccountStatusSnapshot status) {
    if (_saving) return '...';
    final pending = status.pending;
    if (pending != null) {
      return _isRussian
          ? '${_statusLabel(pending)}. Заявка на проверке'
          : '${_statusLabel(pending)}. Request is pending';
    }
    if (status.current == RegistrationAccountType.user) {
      return _isRussian
          ? 'Личный аккаунт. Можно получить статус заказчика'
          : 'Personal account. You can switch to a client status';
    }
    return _isRussian
        ? '${_statusLabel(status.current)}. Доступны подборки и букинг'
        : '${_statusLabel(status.current)}. Selections and booking are available';
  }

  String _dialogTitle() {
    return _isRussian ? 'Выберите статус аккаунта' : 'Choose account status';
  }

  String _statusLabel(RegistrationAccountType type) {
    return switch (type) {
      RegistrationAccountType.user =>
        _isRussian ? 'Личный аккаунт' : 'Personal account',
      RegistrationAccountType.castingDirector =>
        _isRussian ? 'Кастинг-директор' : 'Casting director',
      RegistrationAccountType.castingAgent =>
        _isRussian ? 'Кастинг-агент' : 'Casting agent',
      RegistrationAccountType.directorProducer =>
        _isRussian ? 'Режиссер / продюсер' : 'Director / producer',
      RegistrationAccountType.brandClient =>
        _isRussian ? 'Бренд / заказчик' : 'Brand / client',
      RegistrationAccountType.agency => _isRussian ? 'Агентство' : 'Agency',
      RegistrationAccountType.productionAgency =>
        _isRussian
            ? 'Продакшн / рекламное агентство'
            : 'Production / ad agency',
      RegistrationAccountType.photoVideo =>
        _isRussian ? 'Фотограф / видеограф' : 'Photographer / videographer',
      RegistrationAccountType.scoutBooker =>
        _isRussian ? 'Скаут / буккер' : 'Scout / booker',
    };
  }

  Future<void> _changeStatus(AccountStatusSnapshot status) async {
    if (_saving) return;

    final selected = await showDialog<RegistrationAccountType>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 620),
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          decoration: catalogDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _dialogTitle().toUpperCase(),
                textAlign: TextAlign.center,
                style: _accountCommandStyle(
                  size: 20,
                  spacing: 2.2,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: publicRegistrationAccountTypes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final type = publicRegistrationAccountTypes[index];
                    return _StatusOptionRow(
                      title: _statusLabel(type),
                      subtitle: type == status.pending
                          ? (_isRussian
                                ? 'Заявка на проверке'
                                : 'Request is pending')
                          : null,
                      selected: type == status.current,
                      pending: type == status.pending,
                      onTap: () => Navigator.of(context).pop(type),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null ||
        selected == status.current ||
        selected == status.pending ||
        !mounted) {
      return;
    }

    if (registrationAccountTypeIsClient(selected) && !status.isApprovedClient) {
      final ready = await _ensureOwnerProfileForRequest();
      if (!ready || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(accountStatusServiceProvider).updateStatus(selected);
      ref.invalidate(accountStatusProvider);
      ref.invalidate(accountRoleProvider);
      ref.invalidate(canCreateSelectionsProvider);
      ref.invalidate(accountEntitlementsProvider);
    } catch (e) {
      if (!mounted) return;
      final details = e.toString().trim();
      final message = _isRussian
          ? 'Не удалось отправить заявку. Проверьте SQL для заявок в Supabase.${details.isEmpty ? '' : '\n$details'}'
          : 'Could not send the request. Check the status SQL in Supabase.${details.isEmpty ? '' : '\n$details'}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _ensureOwnerProfileForRequest() async {
    final profile = await ref.read(accountOwnerProfileProvider.future);
    if (profile.hasMinimumForRequest) return true;
    if (!mounted) return false;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AccountProfileEditPage()),
    );
    if (saved == true) {
      ref.invalidate(accountOwnerProfileProvider);
      final updated = await ref.read(accountOwnerProfileProvider.future);
      return updated.hasMinimumForRequest;
    }
    return false;
  }

  void _scheduleRejectedDialog(AccountStatusSnapshot status) {
    final rejected = status.rejected;
    if (rejected == null ||
        status.current != RegistrationAccountType.user ||
        _saving) {
      return;
    }

    final userId = ref.read(supabaseProvider).auth.currentUser?.id ?? 'local';
    final key =
        'account_status_rejected_seen_${userId}_${rejected.storageValue}';
    if (_shownRejectedDialogs.contains(key)) return;
    _shownRejectedDialogs.add(key);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) == true) return;
      await prefs.setBool(key, true);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            decoration: catalogDialogDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isRussian ? 'ЗАЯВКА ОТКЛОНЕНА' : 'REQUEST REJECTED',
                  textAlign: TextAlign.center,
                  style: _accountCommandStyle(
                    size: 20,
                    spacing: 2.2,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isRussian
                      ? 'Заявку на статус “${_statusLabel(rejected)}” отклонили. Сейчас у вас личный аккаунт. Вы можете отправить новую заявку позже.'
                      : 'Your request for “${_statusLabel(rejected)}” was rejected. Your account is personal now. You can send a new request later.',
                  textAlign: TextAlign.center,
                  style: _accountBodyStyle(
                    color: kTextMuted,
                    weight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                BrandPillButton(
                  label: _isRussian ? 'ПОНЯТНО' : 'OK',
                  style: BrandPillStyle.dark,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncStatus = ref.watch(accountStatusProvider);

    return asyncStatus.when(
      loading: () => _AccountEntryCard(
        icon: Icons.badge_rounded,
        title: _title(),
        subtitle: '...',
        onTap: null,
      ),
      error: (_, _) => _AccountEntryCard(
        icon: Icons.badge_rounded,
        title: _title(),
        subtitle: _isRussian
            ? 'Не удалось загрузить статус'
            : 'Could not load status',
        onTap: null,
      ),
      data: (status) {
        _scheduleRejectedDialog(status);
        return _AccountEntryCard(
          icon: Icons.badge_rounded,
          title: _title(),
          subtitle: _subtitle(status),
          onTap: _saving ? null : () => _changeStatus(status),
        );
      },
    );
  }
}

class _DeleteAccountEntryCard extends ConsumerStatefulWidget {
  const _DeleteAccountEntryCard();

  @override
  ConsumerState<_DeleteAccountEntryCard> createState() =>
      _DeleteAccountEntryCardState();
}

class _DeleteAccountEntryCardState
    extends ConsumerState<_DeleteAccountEntryCard> {
  bool _isDeleting = false;

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;

    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          decoration: catalogDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.deleteAccountConfirmTitleUpper,
                textAlign: TextAlign.center,
                style: _accountCommandStyle(
                  color: kTextDanger,
                  size: 20,
                  spacing: 2.2,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.deleteAccountConfirmMessage,
                textAlign: TextAlign.center,
                style: _accountBodyStyle(
                  color: kTextMuted,
                  weight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: BrandPillButton(
                      label: t.cancel,
                      style: BrandPillStyle.light,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrandPillButton(
                      label: t.deleteAccountConfirmActionUpper,
                      style: BrandPillStyle.dark,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(accountDeletionServiceProvider).deleteMyAccount();
      if (!mounted) return;
      context.go(Routes.search);
      await ref.read(supabaseProvider).auth.signOut();
    } on AccountDeletionSetupRequiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.deleteAccountSetupRequired)));
    } on AccountDeletionFailedException catch (e) {
      if (!mounted) return;
      final details = e.message.trim();
      final message = details.isEmpty
          ? t.deleteAccountFailed
          : '${t.deleteAccountFailed}\n$details';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.deleteAccountFailed)));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return _AccountEntryCard(
      icon: Icons.delete_forever_rounded,
      title: t.deleteAccountUpper,
      subtitle: _isDeleting ? '...' : t.deleteAccountSubtitle,
      foregroundColor: kTextDanger,
      onTap: _isDeleting ? null : _deleteAccount,
    );
  }
}

class _BillingEntryCard extends StatelessWidget {
  const _BillingEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return _AccountEntryCard(
      icon: Icons.workspace_premium_rounded,
      title: t.billingTitleUpper,
      subtitle: t.billingAccountEntrySubtitle,
      onTap: onTap,
    );
  }
}

class _DesktopSectionTitle extends StatelessWidget {
  const _DesktopSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _accountCommandStyle(
              size: 24,
              spacing: 2.8,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _accountBodyStyle(
              color: kTextMuted,
              size: 15,
              weight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopEmptyProfilesCard extends StatelessWidget {
  const _DesktopEmptyProfilesCard({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Card(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 168),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: BrandTheme.darkPillGradient,
                  borderRadius: BorderRadius.circular(kCardRadius),
                  boxShadow: BrandTheme.basePillShadow(isDark: true),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: _accountCommandStyle(
                  size: 15,
                  spacing: 2.0,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _accountLocaleText(
                  context,
                  'Выберите тип анкеты и заполните данные для каталога',
                  'Choose a profile type and fill in catalog details',
                ),
                textAlign: TextAlign.center,
                style: _accountBodyStyle(
                  color: kTextMuted,
                  size: 14,
                  weight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountEntryCard extends StatelessWidget {
  const _AccountEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.foregroundColor,
    this.avatarUrl,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? foregroundColor;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final accent = foregroundColor;
    final avatar = avatarUrl?.trim() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: _Card(
        child: Row(
          children: [
            Container(
              width: kProfileSummaryImageSize,
              height: kProfileSummaryImageSize,
              decoration: BoxDecoration(
                gradient: BrandTheme.darkPillGradient,
                borderRadius: BorderRadius.circular(kCardRadius),
                boxShadow: BrandTheme.basePillShadow(isDark: true),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar.isNotEmpty
                  ? _NetworkThumbImage(
                      url: avatar,
                      fit: BoxFit.cover,
                      placeholder: Icon(
                        icon,
                        color: accent ?? Colors.white,
                        size: 28,
                      ),
                    )
                  : Icon(icon, color: accent ?? Colors.white, size: 28),
            ),
            const SizedBox(width: kProfileSummaryGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _accountCommandStyle(
                      color: accent ?? kTextDark,
                      size: 18,
                      spacing: 2.1,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: _accountBodyStyle(
                      color: accent ?? kTextMuted,
                      size: 15,
                      weight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: kProfileVideoPlayIconSize,
              color: kTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddProfileAction extends StatelessWidget {
  const _AddProfileAction({
    required this.label,
    required this.onTap,
    this.onLogout,
    this.logoutLabel,
  });

  final String label;
  final VoidCallback onTap;
  final Future<void> Function()? onLogout;
  final String? logoutLabel;

  @override
  Widget build(BuildContext context) {
    final logout = onLogout;
    final logoutText = logoutLabel?.trim() ?? '';
    final hasLogout = logout != null && logoutText.isNotEmpty;

    return SizedBox(
      height: kProfileAddButtonSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _PlusButton(onTap: onTap),
          ),
          Positioned.fill(
            left: kProfileAddButtonSize + kGap12,
            right: hasLogout
                ? _kAccountLogoutButtonWidth + kGap12
                : kProfileAddButtonSize + kGap12,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  softWrap: false,
                  style: _accountCommandStyle(
                    size: 15,
                    spacing: 2.7,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (hasLogout)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: _kAccountLogoutButtonWidth,
                child: _LogoutButton(label: logoutText, onTap: logout),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlusButton extends StatefulWidget {
  const _PlusButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<_PlusButton> {
  bool _pressed = false;
  bool _flash = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  Future<void> _doFlash() async {
    setState(() => _flash = true);
    await Future.delayed(kProfileFlashDuration);
    if (mounted) setState(() => _flash = false);
  }

  @override
  Widget build(BuildContext context) {
    final glow = _pressed || _flash;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        _doFlash();
        widget.onTap();
      },
      child: AnimatedScale(
        duration: kProfilePlusScaleDuration,
        scale: _pressed ? 0.985 : 1.0,
        child: AnimatedContainer(
          duration: kProfilePlusContainerDuration,
          width: kProfileAddButtonSize,
          height: kProfileAddButtonSize,
          decoration: profileAddButtonDecoration(glow: glow),
          child: const Center(
            child: Text(
              '+',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.label, required this.onTap});

  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        height: kProfileLogoutButtonHeight,
        padding: kProfileLogoutButtonPad,
        decoration: profileLogoutButtonDecoration(),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: _accountCommandStyle(
              color: Colors.white,
              size: 15,
              spacing: 1.6,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyProfileImagePlaceholder extends StatelessWidget {
  const _EmptyProfileImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(decoration: catalogPhotoPlaceholderDecoration());
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.fullName,
    required this.status,
    required this.onTap,
    required this.photoUrl,
    required this.uploadTask,
    required this.onRetryUpload,
    required this.onDismissUpload,
  });

  final String fullName;
  final ProfileStatus status;
  final String? photoUrl;
  final ProfileMediaUploadTask? uploadTask;
  final ValueChanged<ProfileMediaUploadTask> onRetryUpload;
  final ValueChanged<ProfileMediaUploadTask> onDismissUpload;
  final VoidCallback onTap;

  String _statusLabel(AppLocalizations t) {
    switch (status) {
      case ProfileStatus.pending:
        return t.profileStatusPendingUpper;
      case ProfileStatus.approved:
        return t.profileStatusApprovedUpper;
      case ProfileStatus.rejected:
        return t.profileStatusRejectedUpper;
      case ProfileStatus.draft:
        return t.profileStatusDraftUpper;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final hasPhoto = photoUrl?.trim().isNotEmpty ?? false;
    final title = fullName.trim().isEmpty ? '—' : fullName.trim();
    final statusLabel = _statusLabel(t);

    return GestureDetector(
      onTap: onTap,
      child: _Card(
        child: Row(
          children: [
            SizedBox(
              width: kProfileSummaryImageSize,
              height: kProfileSummaryImageSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kProfileImageRadius),
                child: hasPhoto
                    ? _NetworkThumbImage(
                        url: photoUrl!,
                        fit: BoxFit.cover,
                        placeholder: const _EmptyProfileImagePlaceholder(),
                      )
                    : const _EmptyProfileImagePlaceholder(),
              ),
            ),
            const SizedBox(width: kProfileSummaryGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _accountCommandStyle(
                      size: 18,
                      spacing: 1.8,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _accountCommandStyle(
                      color: status == ProfileStatus.rejected
                          ? BrandTheme.redTop
                          : kTextMuted,
                      size: 11,
                      spacing: 1.1,
                      weight: FontWeight.w700,
                    ),
                  ),
                  if (uploadTask != null) ...[
                    const SizedBox(height: 8),
                    _ProfileUploadStatusLine(
                      task: uploadTask!,
                      onRetry: () => onRetryUpload(uploadTask!),
                      onDismiss: () => onDismissUpload(uploadTask!),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: kProfileVideoPlayIconSize,
              color: kTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileUploadStatusLine extends StatelessWidget {
  const _ProfileUploadStatusLine({
    required this.task,
    required this.onRetry,
    required this.onDismiss,
  });

  final ProfileMediaUploadTask task;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  String _mediaLabel(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final parts = <String>[
      if (task.photoCount > 0)
        ru ? '${task.photoCount} фото' : '${task.photoCount} photo',
      if (task.videoCount > 0)
        ru ? '${task.videoCount} видео' : '${task.videoCount} video',
    ];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final isFailed = task.status == ProfileMediaUploadStatus.failed;
    final isDone = task.status == ProfileMediaUploadStatus.completed;
    final label = switch (task.status) {
      ProfileMediaUploadStatus.uploading =>
        ru ? 'Медиа загружаются' : 'Media uploading',
      ProfileMediaUploadStatus.failed =>
        ru ? 'Ошибка загрузки медиа' : 'Media upload failed',
      ProfileMediaUploadStatus.completed =>
        ru ? 'Медиа загружены' : 'Media uploaded',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: pillDecoration(isDark: isFailed, radius: 999).copyWith(
            border: Border.all(
              color: isDone
                  ? BrandTheme.redTop.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task.status == ProfileMediaUploadStatus.uploading) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                '$label: ${_mediaLabel(context)}',
                style: _accountBodyStyle(
                  color: isFailed ? Colors.white : kTextMuted,
                  size: 11,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (isFailed)
          _MiniUploadAction(label: ru ? 'ПОВТОРИТЬ' : 'RETRY', onTap: onRetry),
        if (isFailed || isDone)
          _MiniUploadAction(label: ru ? 'СКРЫТЬ' : 'HIDE', onTap: onDismiss),
      ],
    );
  }
}

class _MiniUploadAction extends StatelessWidget {
  const _MiniUploadAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: pillDecoration(isDark: false, radius: 999),
        child: Text(
          label,
          style: _accountCommandStyle(
            color: kTextDark,
            size: 10,
            spacing: 0.8,
            weight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _NetworkThumbImage extends StatelessWidget {
  const _NetworkThumbImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String url;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final fallback = placeholder ?? const _EmptyProfileImagePlaceholder();
    final trimmedUrl = url.trim();

    if (trimmedUrl.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: trimmedUrl,
      fit: fit,
      memCacheWidth: 240,
      maxWidthDiskCache: 480,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => Container(
        color: kSurfaceLoading,
        alignment: Alignment.center,
        child: const SizedBox(
          width: kProfileFallbackSpinnerSize,
          height: kProfileFallbackSpinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: kProfileFallbackSpinnerStroke,
          ),
        ),
      ),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _kProfileCardPad,
      decoration: catalogCardDecoration(),
      child: child,
    );
  }
}

class _StatusOptionRow extends StatelessWidget {
  const _StatusOptionRow({
    required this.title,
    required this.selected,
    required this.pending,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? BrandTheme.redTop.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.72);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kSearchRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: catalogSearchDecoration(
            borderColor: borderColor,
            borderWidth: selected ? 1.4 : 1,
            radius: kSearchRadius,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _accountBodyStyle(
                        color: kTextDark,
                        size: 16,
                        spacing: 0.3,
                        weight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: _accountBodyStyle(
                          color: kTextMuted,
                          size: 13,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: BrandTheme.redTop,
                  size: 22,
                )
              else if (pending)
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: kTextMuted,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
