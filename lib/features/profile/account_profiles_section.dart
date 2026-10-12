import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/storage_image_variant.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/ui_constants.dart';
import 'profile_model.dart';

/// Profiles (models, actors…) this account represents — the ones visible
/// in the catalogue. Tapping opens the profile page.
class _RepresentedProfile {
  const _RepresentedProfile({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.role,
    required this.city,
  });

  final String id;
  final String name;
  final String photoUrl;
  final String role;
  final String city;

  String subtitle(AppLocalizations t) {
    final roleLabel = switch (profileTypeFromString(role)) {
      ProfessionalProfileType.model => t.profileTypeModel,
      ProfessionalProfileType.actor => t.profileTypeActor,
      ProfessionalProfileType.photographer => t.profileTypePhotographer,
      ProfessionalProfileType.videographer => t.profileTypeVideographer,
      ProfessionalProfileType.stylist => t.profileTypeStylist,
      ProfessionalProfileType.makeupArtist => t.profileTypeMakeupArtist,
      ProfessionalProfileType.hairStylist => t.profileTypeHairStylist,
    };
    return [if (role.isNotEmpty) roleLabel, if (city.isNotEmpty) city].join(' · ');
  }
}

final _representedProfilesProvider = FutureProvider.family
    .autoDispose<List<_RepresentedProfile>, String>((ref, userId) async {
      final sb = ref.read(supabaseProvider);
      final rows = await sb
          .from('catalog_profiles')
          .select('id,full_name,cover_photo_url,photo_urls,profile_roles,city')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(12);
      return (rows as List<dynamic>).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final photos = (m['photo_urls'] as List?)?.cast<String>() ?? const [];
        final cover = (m['cover_photo_url'] ?? '').toString().trim();
        final roles = (m['profile_roles'] as List?)?.cast<String>() ?? const [];
        return _RepresentedProfile(
          id: (m['id'] ?? '').toString(),
          name: (m['full_name'] ?? '').toString().trim(),
          photoUrl: cover.isNotEmpty ? cover : (photos.isEmpty ? '' : photos.first),
          role: roles.isEmpty ? '' : roles.first,
          city: (m['city'] ?? '').toString().trim(),
        );
      }).toList(growable: false);
    });

class AccountProfilesSection extends ConsumerWidget {
  const AccountProfilesSection({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(_representedProfilesProvider(userId));
    final items = async.valueOrNull ?? const <_RepresentedProfile>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(
          (ru ? 'Представляет' : 'Represents').toUpperCase(),
          style: AppText.label.copyWith(color: Tokens.textTertiary),
        ),
        const SizedBox(height: 10),
        for (final p in items)
          InkWell(
            onTap: () => context.push('${Routes.publicModelPrefix}${p.id}'),
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    child: SizedBox(
                      width: 56,
                      height: 72,
                      child: p.photoUrl.isEmpty
                          ? const ColoredBox(
                              color: Tokens.surfaceAlt,
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: Tokens.textTertiary,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: storageImageVariant(p.photoUrl, width: 160),
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => CachedNetworkImage(
                                imageUrl: p.photoUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: Tokens.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name.isEmpty ? (ru ? 'Анкета' : 'Profile') : p.name,
                          style: AppText.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.subtitle(t).isNotEmpty)
                          Text(
                            p.subtitle(t),
                            style: AppText.small.copyWith(color: Tokens.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Tokens.textTertiary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
