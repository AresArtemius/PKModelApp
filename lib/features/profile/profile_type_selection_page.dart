import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_logo.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'profile_model.dart';

class ProfileTypeSelectionPage extends StatelessWidget {
  const ProfileTypeSelectionPage({super.key});

  List<_ProfileTypeOption> _options(AppLocalizations t) {
    return [
      _ProfileTypeOption(
        type: ProfessionalProfileType.model,
        icon: Icons.person_rounded,
        title: t.profileTypeModel,
        subtitle: t.onboardingModelSubtitle,
      ),
      _ProfileTypeOption(
        type: ProfessionalProfileType.actor,
        icon: Icons.theater_comedy_rounded,
        title: t.profileTypeActor,
        subtitle: t.onboardingActorSubtitle,
      ),
      _ProfileTypeOption(
        type: ProfessionalProfileType.photographer,
        icon: Icons.photo_camera_rounded,
        title: t.profileTypePhotographer,
        subtitle: t.onboardingPhotographerSubtitle,
      ),
      _ProfileTypeOption(
        type: ProfessionalProfileType.videographer,
        icon: Icons.videocam_rounded,
        title: t.profileTypeVideographer,
        subtitle: t.onboardingVideographerSubtitle,
      ),
      _ProfileTypeOption(
        type: ProfessionalProfileType.stylist,
        icon: Icons.checkroom_rounded,
        title: t.profileTypeStylist,
        subtitle: t.onboardingStylistSubtitle,
      ),
      _ProfileTypeOption(
        type: ProfessionalProfileType.makeupArtist,
        icon: Icons.palette_rounded,
        title: t.profileTypeMakeupArtist,
        subtitle: t.onboardingMakeupArtistSubtitle,
      ),
      _ProfileTypeOption(
        type: ProfessionalProfileType.hairStylist,
        icon: Icons.content_cut_rounded,
        title: t.profileTypeHairStylist,
        subtitle: t.onboardingHairStylistSubtitle,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final options = _options(t);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: kProfileBackButtonPad,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 22,
                        color: kTextDark,
                      ),
                    ),
                  ),
                ),
                const Center(child: BrandLogo(height: 64)),
                const SizedBox(height: 24),
                Text(
                  t.profileTypeSelectTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: kTextDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t.profileTypeSelectSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: kTextMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < options.length; i++) ...[
                  _ProfileTypeCard(
                    icon: options[i].icon,
                    title: options[i].title,
                    subtitle: options[i].subtitle,
                    action: t.onboardingChooseUpper,
                    selected: i == 0,
                    onTap: () => Navigator.of(context).pop(options[i].type),
                  ),
                  if (i != options.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTypeCard extends StatelessWidget {
  const _ProfileTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final bool selected;
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
                    Text(
                      action,
                      style: TextStyle(
                        color: selected ? Colors.white : BrandTheme.redTop,
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

class _ProfileTypeOption {
  const _ProfileTypeOption({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ProfessionalProfileType type;
  final IconData icon;
  final String title;
  final String subtitle;
}
