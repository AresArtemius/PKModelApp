import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_providers.dart';
import '../../core/onboarding_provider.dart';
import '../../core/roles_provider.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_logo.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

class RoleOnboardingPage extends ConsumerStatefulWidget {
  const RoleOnboardingPage({super.key});

  @override
  ConsumerState<RoleOnboardingPage> createState() => _RoleOnboardingPageState();
}

class _RoleOnboardingPageState extends ConsumerState<RoleOnboardingPage> {
  bool _saving = false;
  String? _error;
  OnboardingAccountType? _selectedType;

  Future<void> _select(OnboardingAccountType type) async {
    if (_saving) return;

    final t = AppLocalizations.of(context)!;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go(Routes.login);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _selectedType = type;
    });

    try {
      await ref
          .read(accountOnboardingServiceProvider)
          .complete(user: user, accountType: type);
      ref.invalidate(needsOnboardingProvider);
      ref.invalidate(accountRoleProvider);
      ref.invalidate(isAdminProvider);
      ref.invalidate(canCreateSelectionsProvider);

      if (!mounted) return;
      context.go(_nextRouteFor(type));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = t.onboardingSaveFailed;
        _selectedType = null;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _nextRouteFor(OnboardingAccountType type) {
    return switch (type) {
      OnboardingAccountType.model => Routes.me,
      OnboardingAccountType.actor => Routes.me,
      OnboardingAccountType.castingAgent => Routes.search,
      OnboardingAccountType.brand => Routes.search,
      OnboardingAccountType.photographer => Routes.search,
      OnboardingAccountType.videographer => Routes.search,
      OnboardingAccountType.stylist => Routes.search,
      OnboardingAccountType.makeupArtist => Routes.search,
      OnboardingAccountType.hairStylist => Routes.search,
      OnboardingAccountType.agency => Routes.search,
    };
  }

  List<_RoleOption> _roleOptions(AppLocalizations t) {
    return [
      _RoleOption(
        type: OnboardingAccountType.model,
        icon: Icons.person_rounded,
        title: t.onboardingModelTitle,
        subtitle: t.onboardingModelSubtitle,
      ),
      _RoleOption(
        type: OnboardingAccountType.actor,
        icon: Icons.theater_comedy_rounded,
        title: t.onboardingActorTitle,
        subtitle: t.onboardingActorSubtitle,
      ),
      _RoleOption(
        type: OnboardingAccountType.castingAgent,
        icon: Icons.manage_search_rounded,
        title: t.onboardingCastingTitle,
        subtitle: t.onboardingCastingSubtitle,
      ),
      _RoleOption(
        type: OnboardingAccountType.brand,
        icon: Icons.storefront_rounded,
        title: t.onboardingBrandTitle,
        subtitle: t.onboardingBrandSubtitle,
      ),
      _RoleOption(
        type: OnboardingAccountType.photographer,
        icon: Icons.photo_camera_rounded,
        title: t.onboardingPhotographerTitle,
        subtitle: t.onboardingPhotographerSubtitle,
      ),
      _RoleOption(
        type: OnboardingAccountType.videographer,
        icon: Icons.videocam_rounded,
        title: t.onboardingVideographerTitle,
        subtitle: t.onboardingVideographerSubtitle,
      ),
      _RoleOption(
        type: OnboardingAccountType.stylist,
        icon: Icons.checkroom_rounded,
        title: t.onboardingStylistTitle,
        subtitle: t.onboardingStylistSubtitle,
      ),
      _RoleOption(
        type: OnboardingAccountType.makeupArtist,
        icon: Icons.palette_rounded,
        title: t.onboardingMakeupArtistTitle,
        subtitle: t.onboardingMakeupArtistSubtitle,
      ),
      _RoleOption(
        type: OnboardingAccountType.hairStylist,
        icon: Icons.content_cut_rounded,
        title: t.onboardingHairStylistTitle,
        subtitle: t.onboardingHairStylistSubtitle,
      ),
    ];
  }

  Widget _buildV2(AppLocalizations t, List<_RoleOption> roleOptions) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final width = MediaQuery.sizeOf(context).width;
    final twoColumns = width >= 760;
    final gutter = width >= 600 ? 32.0 : 20.0;

    final rows = [
      for (var i = 0; i < roleOptions.length; i++)
        _RoleRowV2(
          icon: roleOptions[i].icon,
          title: roleOptions[i].title,
          subtitle: roleOptions[i].subtitle,
          selected: roleOptions[i].type == _selectedType,
          busy: _saving && roleOptions[i].type == _selectedType,
          onTap: () => _select(roleOptions[i].type),
        ),
    ];

    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _saving,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: twoColumns ? 880 : 520),
              child: ListView(
                padding: EdgeInsets.fromLTRB(gutter, 40, gutter, 40),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BrandLogo(height: 44),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    ru
                        ? 'Как вы будете использовать PK Management?'
                        : 'How will you use PK Management?',
                    style: AppText.h1.copyWith(fontSize: twoColumns ? 32 : 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ru
                        ? 'Выберите роль один раз — приложение откроет нужный сценарий. Позже её можно изменить в настройках аккаунта.'
                        : 'Pick a role once and the app opens the right flow. You can change it later in the account settings.',
                    style: AppText.small.copyWith(color: Tokens.textSecondary),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Tokens.accentSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: AppText.small.copyWith(color: Tokens.danger),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (twoColumns)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final row in rows)
                          SizedBox(
                            width: (880 - gutter * 2 - 12) / 2,
                            child: row,
                          ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          rows[i],
                          if (i != rows.length - 1) const SizedBox(height: 10),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final roleOptions = _roleOptions(t);
    if (kIsWeb) return _buildV2(t, roleOptions);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: AbsorbPointer(
              absorbing: _saving,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
                children: [
                  const Center(child: BrandLogo(height: 64)),
                  const SizedBox(height: 26),
                  Text(
                    t.onboardingTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kTextDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.onboardingSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kTextMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.25,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kTextDanger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  for (var i = 0; i < roleOptions.length; i++) ...[
                    _RoleCard(
                      icon: roleOptions[i].icon,
                      title: roleOptions[i].title,
                      subtitle: roleOptions[i].subtitle,
                      action: t.onboardingChooseUpper,
                      selected: roleOptions[i].type == _selectedType,
                      busy: _saving && roleOptions[i].type == _selectedType,
                      onTap: () => _select(roleOptions[i].type),
                    ),
                    if (i != roleOptions.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          if (_saving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.12),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: pillDecoration(isDark: false, radius: 22),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      BrandTheme.redTop,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: pillDecoration(isDark: selected, radius: kCardRadius)
              .copyWith(
                border: Border.all(
                  color: selected ? BrandTheme.redTop : kBorderColor,
                  width: selected ? 2 : 1,
                ),
              ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: BrandTheme.darkPillGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? Colors.white : kTextDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: selected ? Colors.white70 : kTextMuted,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            action,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : BrandTheme.redTop,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              fontSize: 12,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: selected ? Colors.white70 : kTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption {
  const _RoleOption({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final OnboardingAccountType type;
  final IconData icon;
  final String title;
  final String subtitle;
}


/// v2 role option: hairline card with an icon circle, title and subtitle;
/// the chosen one gets an ink border while it saves.
class _RoleRowV2 extends StatefulWidget {
  const _RoleRowV2({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_RoleRowV2> createState() => _RoleRowV2State();
}

class _RoleRowV2State extends State<_RoleRowV2> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: Tokens.fast,
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: selected
                  ? Tokens.surfaceAlt
                  : (_hovered ? Tokens.surface : Tokens.bg),
              borderRadius: BorderRadius.circular(Tokens.radiusLg),
              border: Border.all(
                color: selected ? Tokens.ink : Tokens.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? Tokens.ink : Tokens.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 22,
                    color: selected ? Colors.white : Tokens.text,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppText.small.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Tokens.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: Tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (widget.busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Tokens.ink),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: _hovered ? Tokens.text : Tokens.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
