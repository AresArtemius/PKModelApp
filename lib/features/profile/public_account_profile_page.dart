import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account_profile_service.dart';
import '../../core/router.dart';
import '../../core/roles_provider.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

const double _kPublicAccountMaxWidth = 760;
const double _kPublicAccountAvatarSize = 104;

final publicAccountProfileProvider =
    FutureProvider.family<PublicAccountProfile?, String>((ref, rawTag) async {
      final tag = normalizeAccountTag(rawTag);
      if (tag.isEmpty) return null;
      final sb = ref.read(supabaseProvider);

      try {
        final rows = await sb.rpc<List<dynamic>>(
          'get_public_account_profile',
          params: {'p_account_tag': tag},
        );
        if (rows.isEmpty) return null;
        return PublicAccountProfile.fromMap(
          Map<String, dynamic>.from(rows.first as Map),
        );
      } on PostgrestException catch (e) {
        if (!SupabaseCompat.isMissingRpc(e, 'get_public_account_profile')) {
          rethrow;
        }
      }

      try {
        final row = await sb
            .from('user_profiles')
            .select(
              'user_id,account_tag,avatar_url,full_name,company_name,position,account_type,city,country,website,social_url,bio',
            )
            .eq('account_tag', tag)
            .eq(
              'account_tag_visibility',
              AccountTagVisibility.public.storageValue,
            )
            .limit(1)
            .maybeSingle();
        return PublicAccountProfile.fromMap(row);
      } on PostgrestException {
        return null;
      }
    });

class PublicAccountProfile {
  const PublicAccountProfile({
    required this.userId,
    required this.accountTag,
    required this.avatarUrl,
    required this.fullName,
    required this.companyName,
    required this.position,
    required this.accountType,
    required this.city,
    required this.country,
    required this.website,
    required this.socialUrl,
    required this.bio,
  });

  final String userId;
  final String accountTag;
  final String avatarUrl;
  final String fullName;
  final String companyName;
  final String position;
  final RegistrationAccountType accountType;
  final String city;
  final String country;
  final String website;
  final String socialUrl;
  final String bio;

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (companyName.isNotEmpty) return companyName;
    if (position.isNotEmpty) return position;
    return '@$accountTag';
  }

  String get locationLabel =>
      [city, country].where((part) => part.isNotEmpty).join(', ');

  factory PublicAccountProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PublicAccountProfile.empty();
    String value(String key) => (map[key] ?? '').toString().trim();
    return PublicAccountProfile(
      userId: value('user_id'),
      accountTag: value('account_tag'),
      avatarUrl: value('avatar_url'),
      fullName: value('full_name'),
      companyName: value('company_name'),
      position: value('position'),
      accountType: registrationAccountTypeFromStorage(value('account_type')),
      city: value('city'),
      country: value('country'),
      website: value('website'),
      socialUrl: value('social_url'),
      bio: value('bio'),
    );
  }

  const PublicAccountProfile.empty()
    : userId = '',
      accountTag = '',
      avatarUrl = '',
      fullName = '',
      companyName = '',
      position = '',
      accountType = RegistrationAccountType.user,
      city = '',
      country = '',
      website = '',
      socialUrl = '',
      bio = '';
}

class PublicAccountProfilePage extends ConsumerWidget {
  const PublicAccountProfilePage({super.key, required this.rawTag});

  final String rawTag;

  bool _isRussian(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
  }

  String _accountTypeLabel(BuildContext context, RegistrationAccountType type) {
    final ru = _isRussian(context);
    return switch (type) {
      RegistrationAccountType.user => ru ? 'Участник' : 'Talent account',
      RegistrationAccountType.castingDirector =>
        ru ? 'Кастинг-директор' : 'Casting director',
      RegistrationAccountType.castingAgent =>
        ru ? 'Кастинг-агент' : 'Casting agent',
      RegistrationAccountType.directorProducer =>
        ru ? 'Режиссер / продюсер' : 'Director / producer',
      RegistrationAccountType.brandClient =>
        ru ? 'Бренд / клиент' : 'Brand / client',
      RegistrationAccountType.agency => ru ? 'Агентство' : 'Agency',
      RegistrationAccountType.productionAgency =>
        ru ? 'Продакшн' : 'Production',
      RegistrationAccountType.photoVideo =>
        ru ? 'Фото / видео' : 'Photo / video',
      RegistrationAccountType.scoutBooker =>
        ru ? 'Скаут / букер' : 'Scout / booker',
    };
  }

  TextStyle _commandStyle({
    double size = 16,
    Color color = kTextDark,
    double spacing = 1.1,
    FontWeight weight = FontWeight.w700,
  }) {
    return BrandTheme.pillText.copyWith(
      color: color,
      fontSize: size,
      letterSpacing: spacing,
      fontWeight: weight,
    );
  }

  TextStyle _bodyStyle({
    double size = 15,
    Color color = kTextMuted,
    FontWeight weight = FontWeight.w600,
    double height = 1.25,
  }) {
    return TextStyle(
      color: color,
      fontSize: size,
      letterSpacing: 0,
      fontWeight: weight,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = normalizeAccountTag(rawTag);
    final ru = _isRussian(context);
    final profileAsync = ref.watch(publicAccountProfileProvider(tag));

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _kPublicAccountMaxWidth,
                ),
                child: profileAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _PublicAccountMessage(
                    title: ru ? 'НЕ УДАЛОСЬ ОТКРЫТЬ' : 'CAN NOT OPEN',
                    message: error.toString(),
                    actionLabel: ru ? 'В КАТАЛОГ' : 'CATALOG',
                    onAction: () => context.go(Routes.search),
                  ),
                  data: (profile) {
                    if (profile == null || profile.accountTag.isEmpty) {
                      return _PublicAccountMessage(
                        title: ru ? 'АККАУНТ НЕ НАЙДЕН' : 'ACCOUNT NOT FOUND',
                        message: ru
                            ? 'Этот @tag скрыт или еще не создан.'
                            : 'This @tag is hidden or does not exist yet.',
                        actionLabel: ru ? 'В КАТАЛОГ' : 'CATALOG',
                        onAction: () => context.go(Routes.search),
                      );
                    }

                    return ListView(
                      padding: kMyProfilePagePad,
                      children: [
                        BrandAdminHeader(
                          title: '@${profile.accountTag}',
                          onBack: () => context.go(Routes.search),
                        ),
                        const SizedBox(height: kGap14),
                        Container(
                          padding: kLoginCardPad,
                          decoration: catalogCardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PublicAccountHero(
                                profile: profile,
                                accountTypeLabel: _accountTypeLabel(
                                  context,
                                  profile.accountType,
                                ),
                                commandStyle: _commandStyle,
                                bodyStyle: _bodyStyle,
                              ),
                              if (profile.bio.isNotEmpty) ...[
                                const SizedBox(height: kGap16),
                                _PublicAccountSection(
                                  title: ru ? 'ОБ АККАУНТЕ' : 'ABOUT',
                                  commandStyle: _commandStyle,
                                  child: Text(
                                    profile.bio,
                                    style: _bodyStyle(
                                      color: kTextDark,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (profile.website.isNotEmpty ||
                                  profile.socialUrl.isNotEmpty) ...[
                                const SizedBox(height: kGap16),
                                _PublicAccountSection(
                                  title: ru ? 'ССЫЛКИ' : 'LINKS',
                                  commandStyle: _commandStyle,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (profile.website.isNotEmpty)
                                        _PublicAccountInfoLine(
                                          icon: Icons.language_rounded,
                                          text: profile.website,
                                          bodyStyle: _bodyStyle,
                                        ),
                                      if (profile.socialUrl.isNotEmpty) ...[
                                        if (profile.website.isNotEmpty)
                                          const SizedBox(height: kGap10),
                                        _PublicAccountInfoLine(
                                          icon: Icons.alternate_email_rounded,
                                          text: profile.socialUrl,
                                          bodyStyle: _bodyStyle,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: kGap16),
                              BrandPillButton(
                                label: ru ? 'НАПИСАТЬ' : 'MESSAGE',
                                style: BrandPillStyle.dark,
                                onTap: () {
                                  final loggedIn =
                                      Supabase
                                          .instance
                                          .client
                                          .auth
                                          .currentSession !=
                                      null;
                                  context.go(
                                    loggedIn
                                        ? Routes.chats
                                        : Routes.authRequired,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicAccountHero extends StatelessWidget {
  const _PublicAccountHero({
    required this.profile,
    required this.accountTypeLabel,
    required this.commandStyle,
    required this.bodyStyle,
  });

  final PublicAccountProfile profile;
  final String accountTypeLabel;
  final TextStyle Function({
    Color color,
    double size,
    double spacing,
    FontWeight weight,
  })
  commandStyle;
  final TextStyle Function({
    Color color,
    double size,
    FontWeight weight,
    double height,
  })
  bodyStyle;

  @override
  Widget build(BuildContext context) {
    final location = profile.locationLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PublicAccountAvatar(profile: profile),
        const SizedBox(width: kGap14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: commandStyle(size: 24, spacing: 1.5),
              ),
              const SizedBox(height: kGap6),
              Text(
                '@${profile.accountTag}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: commandStyle(
                  size: 14,
                  spacing: 0.8,
                  color: BrandTheme.redTop,
                ),
              ),
              const SizedBox(height: kGap10),
              Wrap(
                spacing: kGap8,
                runSpacing: kGap8,
                children: [
                  _PublicAccountBadge(text: accountTypeLabel),
                  if (profile.position.isNotEmpty)
                    _PublicAccountBadge(text: profile.position),
                  if (location.isNotEmpty) _PublicAccountBadge(text: location),
                ],
              ),
              if (profile.companyName.isNotEmpty &&
                  profile.companyName != profile.displayName) ...[
                const SizedBox(height: kGap10),
                Text(
                  profile.companyName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle(color: kTextDark, weight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PublicAccountAvatar extends StatelessWidget {
  const _PublicAccountAvatar({required this.profile});

  final PublicAccountProfile profile;

  String get _fallback {
    final source = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : profile.accountTag.trim();
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '@';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kPublicAccountAvatarSize,
      height: _kPublicAccountAvatarSize,
      decoration: BoxDecoration(
        gradient: BrandTheme.darkPillGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: BrandTheme.basePillShadow(isDark: true),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: profile.avatarUrl.isEmpty
          ? Text(
              _fallback,
              style: BrandTheme.pillText.copyWith(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            )
          : CachedNetworkImage(
              imageUrl: profile.avatarUrl,
              fit: BoxFit.cover,
              width: _kPublicAccountAvatarSize,
              height: _kPublicAccountAvatarSize,
              errorWidget: (_, _, _) => Text(
                _fallback,
                style: BrandTheme.pillText.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
    );
  }
}

class _PublicAccountBadge extends StatelessWidget {
  const _PublicAccountBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pillDecoration(
        isDark: false,
        radius: 999,
      ).copyWith(border: Border.all(color: kBorderColor, width: 1)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: BrandTheme.pillText.copyWith(
          color: kTextDark,
          fontSize: 12,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PublicAccountSection extends StatelessWidget {
  const _PublicAccountSection({
    required this.title,
    required this.child,
    required this.commandStyle,
  });

  final String title;
  final Widget child;
  final TextStyle Function({
    Color color,
    double size,
    double spacing,
    FontWeight weight,
  })
  commandStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: pillDecoration(
        isDark: false,
        radius: kCardRadius,
      ).copyWith(border: Border.all(color: kBorderColor, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: commandStyle(size: 13, spacing: 1.1)),
          const SizedBox(height: kGap10),
          child,
        ],
      ),
    );
  }
}

class _PublicAccountInfoLine extends StatelessWidget {
  const _PublicAccountInfoLine({
    required this.icon,
    required this.text,
    required this.bodyStyle,
  });

  final IconData icon;
  final String text;
  final TextStyle Function({
    Color color,
    double size,
    FontWeight weight,
    double height,
  })
  bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kTextMuted, size: 20),
        const SizedBox(width: kGap10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: bodyStyle(color: kTextDark, weight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _PublicAccountMessage extends StatelessWidget {
  const _PublicAccountMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: kMyProfilePagePad,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: kLoginCardPad,
            decoration: catalogCardDecoration(),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: BrandTheme.pillText.copyWith(
                    color: kTextDark,
                    fontSize: 20,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: kGap12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: kTextMuted,
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: kGap16),
                BrandPillButton(
                  label: actionLabel,
                  style: BrandPillStyle.dark,
                  onTap: onAction,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
