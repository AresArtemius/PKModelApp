import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error_mapper.dart';
import '../../core/admin_action_log_service.dart';
import '../../core/admin_dashboard_counts_provider.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../core/roles_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import 'admin_style.dart';
import 'package:video_player/video_player.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_model.dart';
import '../profile/profile_supabase_schema.dart';

const int _moderationMediaCacheWidth = 280;
const double _moderationMediaSize = 64;
const double _moderationMediaRadius = 16;
const double _moderationDesktopBreakpoint = 900;
const double _moderationDesktopMaxWidth = 1540;
const double _moderationDesktopListWidth = 430;
const double _moderationDesktopDetailBreakpoint = 1040;

List<String> _mergeUniqueMedia(List<String> published, List<String> pending) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in [...published, ...pending]) {
    final url = raw.trim();
    if (url.isEmpty || !seen.add(url)) continue;
    result.add(url);
  }
  return result;
}

List<String> _alignedLabels(
  List<String> labels,
  int length, {
  required String fallback,
}) {
  return [
    for (var i = 0; i < length; i++)
      if (i < labels.length && labels[i].trim().isNotEmpty)
        labels[i].trim()
      else
        fallback,
  ];
}

String _coverPhotoFrom(String preferred, List<String> photoUrls) {
  final cover = preferred.trim();
  final photos = photoUrls.map((e) => e.trim()).where((e) => e.isNotEmpty);
  if (cover.isNotEmpty && photos.contains(cover)) return cover;
  return photos.isEmpty ? '' : photos.first;
}

List<String> _photosWithCoverFirst(
  List<String> photoUrls,
  String preferredCover,
) {
  final cover = _coverPhotoFrom(preferredCover, photoUrls);
  if (cover.isEmpty) return photoUrls;
  return [cover, ...photoUrls.where((url) => url.trim() != cover)];
}

String _moderationCoverLabel(BuildContext context) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  return ru ? 'ГЛАВНОЕ ФОТО' : 'COVER PHOTO';
}

String _moderationCoverHint(BuildContext context) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  return ru
      ? 'Это фото станет обложкой после одобрения'
      : 'This photo will become the cover after approval';
}

String _adminSupabaseErrorText(Object error, AppLocalizations t) {
  if (error is PostgrestException) {
    final parts = <String>[error.message.trim()];
    final details = (error.details ?? '').toString().trim();
    final hint = (error.hint ?? '').trim();
    final code = (error.code ?? '').trim();
    if (details.isNotEmpty) parts.add(details);
    if (hint.isNotEmpty) parts.add(hint);
    if (code.isNotEmpty) parts.add('code: $code');
    parts.removeWhere((part) => part.isEmpty);
    if (parts.isNotEmpty) return parts.join('\n');
  }
  return AppErrorMapper.message(error, t);
}

final pendingProfilesProvider =
    FutureProvider.autoDispose<List<MyProfileState>>((ref) async {
      ref.watch(authStateProvider);
      final sb = ref.read(supabaseProvider);

      Future<List<dynamic>> loadViaRpc() async {
        return await sb.rpc('pending_profiles_for_moderation');
      }

      Future<List<dynamic>> load({
        required bool includeBirthDate,
        required bool includeProfessional,
        required bool includeVerification,
        required bool includePendingMedia,
      }) async {
        final query = sb
            .from(ProfileSupabaseSchema.table)
            .select(
              ProfileSupabaseSchema.selectModeration(
                includeBirthDate: includeBirthDate,
                includeProfessional: includeProfessional,
                includeVerification: includeVerification,
                includePendingMedia: includePendingMedia,
              ),
            );

        return query.eq('status', 'pending').limit(200);
      }

      List<dynamic> rows = const <dynamic>[];
      var includeVerification = true;
      var includePendingMedia = true;
      var includeBirthDate = true;
      var includeProfessional = true;
      while (true) {
        try {
          try {
            rows = await loadViaRpc();
          } on PostgrestException catch (e) {
            if (!SupabaseCompat.isMissingRpc(
              e,
              'pending_profiles_for_moderation',
            )) {
              rethrow;
            }
            rows = await load(
              includeBirthDate: includeBirthDate,
              includeProfessional: includeProfessional,
              includeVerification: includeVerification,
              includePendingMedia: includePendingMedia,
            );
          }
          break;
        } on PostgrestException catch (e) {
          final missingVerification =
              includeVerification &&
              ProfileSupabaseSchema.isMissingVerificationColumn(e);
          final missingPendingMedia =
              includePendingMedia &&
              ProfileSupabaseSchema.isMissingPendingMediaColumn(e);
          final missingBirthDate =
              ProfileSupabaseSchema.isMissingBirthDateColumn(e);
          final missingProfessional =
              includeProfessional &&
              ProfileSupabaseSchema.isMissingProfessionalColumn(e);

          if (!missingVerification &&
              !missingPendingMedia &&
              !missingBirthDate &&
              !missingProfessional) {
            rethrow;
          }

          if (missingVerification) includeVerification = false;
          if (missingPendingMedia) includePendingMedia = false;
          if (missingBirthDate) includeBirthDate = false;
          if (missingProfessional) includeProfessional = false;
        }
      }

      return rows
          .map((row) => MyProfileState.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    });

void _refreshModerationQueues(WidgetRef ref) {
  ref.invalidate(pendingProfilesProvider);
  ref.invalidate(adminDashboardCountsProvider);
}

class ModerationAdminPage extends ConsumerStatefulWidget {
  const ModerationAdminPage({super.key});

  @override
  ConsumerState<ModerationAdminPage> createState() =>
      _ModerationAdminPageState();
}

class _ModerationAdminPageState extends ConsumerState<ModerationAdminPage> {
  String? _selectedProfileId;

  Future<void> _approveProfile(
    WidgetRef ref, {
    required MyProfileState profile,
  }) async {
    final sb = ref.read(supabaseProvider);
    final profileId = profile.id;
    final photoUrls = _mergeUniqueMedia(
      profile.photoUrls,
      profile.pendingPhotoUrls,
    );
    final photoCategoryLabels = [
      ..._alignedLabels(
        profile.photoCategoryLabels,
        profile.photoUrls.length,
        fallback: 'Портфолио',
      ),
      ..._alignedLabels(
        profile.pendingPhotoCategoryLabels,
        profile.pendingPhotoUrls.length,
        fallback: 'Портфолио',
      ),
    ];
    final videoUrls = _mergeUniqueMedia(
      profile.videoUrls,
      profile.pendingVideoUrls,
    );
    final videoCategoryLabels = [
      ..._alignedLabels(
        profile.videoCategoryLabels,
        profile.videoUrls.length,
        fallback: 'Видео',
      ),
      ..._alignedLabels(
        profile.pendingVideoCategoryLabels,
        profile.pendingVideoUrls.length,
        fallback: 'Видео',
      ),
    ];
    final preferredCover = profile.pendingCoverPhotoUrl.trim().isNotEmpty
        ? profile.pendingCoverPhotoUrl
        : profile.coverPhotoUrl;
    final preferredCoverFocalX = profile.pendingCoverPhotoUrl.trim().isNotEmpty
        ? profile.pendingCoverPhotoFocalX
        : profile.coverPhotoFocalX;
    final preferredCoverFocalY = profile.pendingCoverPhotoUrl.trim().isNotEmpty
        ? profile.pendingCoverPhotoFocalY
        : profile.coverPhotoFocalY;
    final preferredShowreel = profile.pendingShowreelUrl.trim().isNotEmpty
        ? profile.pendingShowreelUrl
        : profile.showreelUrl;

    try {
      await sb
          .from('profiles')
          .update(<String, dynamic>{
            'status': 'approved',
            'moderation_comment': null,
            'photo_urls': photoUrls,
            'photo_category_labels': photoCategoryLabels,
            'cover_photo_url': _coverPhotoFrom(preferredCover, photoUrls),
            'cover_photo_focal_x': preferredCoverFocalX.clamp(-1.0, 1.0),
            'cover_photo_focal_y': preferredCoverFocalY.clamp(-1.0, 1.0),
            'video_urls': videoUrls,
            'video_preview_urls': _mergeUniqueMedia(
              profile.videoPreviewUrls,
              profile.pendingVideoPreviewUrls,
            ),
            'video_category_labels': videoCategoryLabels,
            'showreel_url': videoUrls.contains(preferredShowreel.trim())
                ? preferredShowreel.trim()
                : '',
            'showreel_preview_url': videoUrls.contains(preferredShowreel.trim())
                ? (profile.pendingShowreelPreviewUrl.trim().isNotEmpty
                      ? profile.pendingShowreelPreviewUrl.trim()
                      : profile.showreelPreviewUrl.trim())
                : '',
            'pending_photo_urls': const <String>[],
            'pending_cover_photo_url': '',
            'pending_cover_photo_focal_x': 0,
            'pending_cover_photo_focal_y': -0.72,
            'pending_video_urls': const <String>[],
            'pending_video_preview_urls': const <String>[],
            'pending_photo_category_labels': const <String>[],
            'pending_video_category_labels': const <String>[],
            'pending_showreel_url': '',
            'pending_showreel_preview_url': '',
            'has_pending_media': false,
          })
          .eq('id', profileId);
    } on PostgrestException catch (directError) {
      if (directError.code == '22P02') rethrow;
      await sb.rpc(
        'admin_publish_profile',
        params: {'p_profile_id': profileId},
      );
    }

    await AdminActionLogService(sb).log(
      actionType: 'profile_approved',
      title: 'Анкета одобрена',
      description: profile.fullName.trim(),
      targetTable: 'profiles',
      targetId: profileId,
      targetText: profile.fullName.trim(),
      status: 'approved',
    );
    _refreshModerationQueues(ref);
  }

  Future<void> _rejectProfile(
    WidgetRef ref, {
    required String profileId,
    required String reason,
  }) async {
    final sb = ref.read(supabaseProvider);
    final comment = reason.trim();

    await sb
        .from('profiles')
        .update(<String, dynamic>{
          'status': 'rejected',
          'moderation_comment': comment,
        })
        .eq('id', profileId);

    await AdminActionLogService(sb).log(
      actionType: 'profile_rejected',
      title: 'Анкета отклонена',
      description: comment,
      targetTable: 'profiles',
      targetId: profileId,
      targetText: profileId,
      status: 'rejected',
    );
    _refreshModerationQueues(ref);
  }

  Future<String?> _askRejectReason(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _RejectReasonDialog(),
    );
  }

  Future<void> _openProfileDetails(
    BuildContext context,
    WidgetRef ref,
    MyProfileState profile,
  ) async {
    final t = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModerationProfileDetailsSheet(
        profile: profile,
        onApprove: () async {
          try {
            await _approveProfile(ref, profile: profile);
            if (context.mounted) Navigator.of(context).pop();
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_adminSupabaseErrorText(e, t))),
            );
          }
        },
        onReject: () async {
          try {
            final reason = await _askRejectReason(context);
            if (!context.mounted || reason == null) return;
            await _rejectProfile(ref, profileId: profile.id, reason: reason);
            if (context.mounted) Navigator.of(context).pop();
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppErrorMapper.message(e, t))),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isAdminAsync = ref.watch(isAdminProvider);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _moderationDesktopBreakpoint;

    return Scaffold(
      bottomNavigationBar: null,
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                kPagePadH,
                kPagePadTop,
                kPagePadH,
                kPagePadBottom,
              ),
              child: Column(
                children: [
                  BrandAdminHeader(
                    title: t.adminModerationUpper,
                    onBack: () => context.go('/admin'),
                  ),
                  const SizedBox(height: kGap16),

                  Expanded(
                    child: isAdminAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => AdminMessageCard(
                        text: AppErrorMapper.message(e, t),
                        isError: true,
                      ),
                      data: (isAdmin) {
                        if (!isAdmin) {
                          // Текст не локализируем тут, чтобы не добавлять новые ключи без твоего запроса
                          return const AdminMessageCard(
                            text: 'ADMINS ONLY',
                            isError: true,
                          );
                        }

                        final pendingAsync = ref.watch(pendingProfilesProvider);
                        return pendingAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => AdminMessageCard(
                            text: AppErrorMapper.message(e, t),
                            isError: true,
                          ),
                          data: (items) {
                            if (items.isEmpty) {
                              final ru =
                                  Localizations.localeOf(
                                    context,
                                  ).languageCode ==
                                  'ru';
                              return AdminMessageCard(
                                text: ru ? 'ЗАЯВОК НЕТ' : 'NO REQUESTS',
                              );
                            }

                            final selected = items.firstWhere(
                              (item) => item.id == _selectedProfileId,
                              orElse: () => items.first,
                            );
                            if (_selectedProfileId != selected.id) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(
                                  () => _selectedProfileId = selected.id,
                                );
                              });
                            }

                            Future<void> approve(MyProfileState profile) async {
                              try {
                                await _approveProfile(ref, profile: profile);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _adminSupabaseErrorText(e, t),
                                    ),
                                  ),
                                );
                              }
                            }

                            Future<void> reject(MyProfileState profile) async {
                              try {
                                final reason = await _askRejectReason(context);
                                if (!context.mounted || reason == null) return;
                                await _rejectProfile(
                                  ref,
                                  profileId: profile.id,
                                  reason: reason,
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppErrorMapper.message(e, t)),
                                  ),
                                );
                              }
                            }

                            if (isDesktop) {
                              return _ModerationDesktopLayout(
                                items: items,
                                selected: selected,
                                onSelect: (profile) {
                                  setState(
                                    () => _selectedProfileId = profile.id,
                                  );
                                },
                                onApprove: approve,
                                onReject: reject,
                              );
                            }

                            return _ModerationRequestList(
                              items: items,
                              selectedId: null,
                              onTap: (profile) =>
                                  _openProfileDetails(context, ref, profile),
                              onApprove: approve,
                              onReject: reject,
                              showInlineActions: true,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationProfileDetailsSheet extends StatelessWidget {
  const _ModerationProfileDetailsSheet({
    required this.profile,
    required this.onApprove,
    required this.onReject,
  });

  final MyProfileState profile;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final photos = _photosWithCoverFirst(
      _mergeUniqueMedia(profile.photoUrls, profile.pendingPhotoUrls),
      profile.pendingCoverPhotoUrl.trim().isNotEmpty
          ? profile.pendingCoverPhotoUrl
          : profile.coverPhotoUrl,
    );
    final videos = _mergeUniqueMedia(
      profile.videoUrls,
      profile.pendingVideoUrls,
    );
    final videoThumbs = _mergeUniqueMedia(
      profile.videoPreviewUrls,
      profile.pendingVideoPreviewUrls,
    );
    final media = <_ModerationMediaItem>[
      for (var i = 0; i < photos.length; i += 1)
        _ModerationMediaItem.photo(photos[i], isCover: i == 0),
      for (var i = 0; i < videos.length; i += 1)
        _ModerationMediaItem.video(
          videoUrl: videos[i],
          previewUrl: i < videoThumbs.length ? videoThumbs[i] : '',
        ),
    ];

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        ru ? 'АНКЕТА НА МОДЕРАЦИИ' : 'PROFILE REVIEW',
                        textAlign: TextAlign.center,
                        style: adminCommandStyle(size: 16, letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  children: [
                    if (media.isNotEmpty)
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: media.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (_, index) => _ModerationLargeMedia(
                            item: media[index],
                            media: media,
                            initialIndex: index,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 180,
                        decoration: profileImagePlaceholderDecoration(),
                      ),
                    if (media.isNotEmpty && media.first.isCover) ...[
                      const SizedBox(height: 10),
                      _ModerationCoverHintLine(
                        text: _moderationCoverHint(context),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      profile.fullName.trim().isEmpty
                          ? profile.id
                          : profile.fullName.trim(),
                      style: adminCommandStyle(size: 23, letterSpacing: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${profile.displayAge} • ${profile.height} cm • ${profile.city} ${profile.country}',
                      style: adminBodyStyle(weight: FontWeight.w800, size: 15),
                    ),
                    const SizedBox(height: 14),
                    _ModerationDetailLine(
                      label: ru ? 'Параметры' : 'Measurements',
                      value:
                          '${profile.bust} / ${profile.waist} / ${profile.hips}, ${profile.shoeSize}',
                    ),
                    _ModerationDetailLine(
                      label: ru ? 'Внешность' : 'Appearance',
                      value: '${profile.eyeColor}, ${profile.hairColor}',
                    ),
                    if (profile.resume.trim().isNotEmpty)
                      _ModerationDetailLine(
                        label: ru ? 'О себе' : 'About',
                        value: profile.resume.trim(),
                      ),
                    if (profile.experience.trim().isNotEmpty)
                      _ModerationDetailLine(
                        label: ru ? 'Опыт' : 'Experience',
                        value: profile.experience.trim(),
                      ),
                    if (profile.skills.trim().isNotEmpty)
                      _ModerationDetailLine(
                        label: ru ? 'Навыки' : 'Skills',
                        value: profile.skills.trim(),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: BrandTheme.pillHeight,
                        child: ElevatedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close_rounded),
                          label: Text(t.moderationRejectActionUpper),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: BrandTheme.pillHeight,
                        child: ElevatedButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(t.profileStatusApprovedUpper),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModerationDesktopLayout extends StatelessWidget {
  const _ModerationDesktopLayout({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onApprove,
    required this.onReject,
  });

  final List<MyProfileState> items;
  final MyProfileState selected;
  final ValueChanged<MyProfileState> onSelect;
  final Future<void> Function(MyProfileState profile) onApprove;
  final Future<void> Function(MyProfileState profile) onReject;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _moderationDesktopMaxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _moderationDesktopListWidth,
              child: _ModerationDesktopQueuePanel(
                items: items,
                selectedId: selected.id,
                onTap: onSelect,
                onApprove: onApprove,
                onReject: onReject,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _ModerationProfileDetailsPanel(
                profile: selected,
                onApprove: () => onApprove(selected),
                onReject: () => onReject(selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModerationDesktopQueuePanel extends StatelessWidget {
  const _ModerationDesktopQueuePanel({
    required this.items,
    required this.selectedId,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  final List<MyProfileState> items;
  final String? selectedId;
  final ValueChanged<MyProfileState> onTap;
  final Future<void> Function(MyProfileState profile) onApprove;
  final Future<void> Function(MyProfileState profile) onReject;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';

    return Container(
      decoration: catalogCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ru ? 'ОЧЕРЕДЬ' : 'QUEUE',
                    style: adminCommandStyle(size: 17, letterSpacing: 1.2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: kTextDark,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                ru
                    ? 'Выберите заявку, чтобы проверить анкету и медиа.'
                    : 'Select a request to review profile data and media.',
                style: adminBodyStyle(
                  size: 12,
                  weight: FontWeight.w700,
                  color: kTextMuted,
                ),
              ),
            ),
          ),
          Expanded(
            child: _ModerationRequestList(
              items: items,
              selectedId: selectedId,
              onTap: onTap,
              onApprove: onApprove,
              onReject: onReject,
              showInlineActions: false,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationRequestList extends StatelessWidget {
  const _ModerationRequestList({
    required this.items,
    required this.selectedId,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.showInlineActions,
    this.padding = EdgeInsets.zero,
  });

  final List<MyProfileState> items;
  final String? selectedId;
  final ValueChanged<MyProfileState> onTap;
  final Future<void> Function(MyProfileState profile) onApprove;
  final Future<void> Function(MyProfileState profile) onReject;
  final bool showInlineActions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return ListView.separated(
      padding: padding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = items[i];
        return _ModerationRequestCard(
          profile: p,
          selected: selectedId == p.id,
          showInlineActions: showInlineActions,
          onTap: () => onTap(p),
          onApprove: () => onApprove(p),
          onReject: () => onReject(p),
          approveTooltip: t.profileStatusApprovedUpper,
          rejectTooltip: t.moderationRejectActionUpper,
        );
      },
    );
  }
}

class _ModerationRequestCard extends StatelessWidget {
  const _ModerationRequestCard({
    required this.profile,
    required this.selected,
    required this.showInlineActions,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.approveTooltip,
    required this.rejectTooltip,
  });

  final MyProfileState profile;
  final bool selected;
  final bool showInlineActions;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final String approveTooltip;
  final String rejectTooltip;

  @override
  Widget build(BuildContext context) {
    final previewPhotos = _photosWithCoverFirst(
      profile.pendingPhotoUrls.isNotEmpty
          ? profile.pendingPhotoUrls
          : profile.photoUrls,
      profile.pendingCoverPhotoUrl.trim().isNotEmpty
          ? profile.pendingCoverPhotoUrl
          : profile.coverPhotoUrl,
    );
    final previewVideos = profile.pendingVideoUrls.isNotEmpty
        ? profile.pendingVideoUrls
        : profile.videoUrls;
    final previewVideoThumbs = profile.pendingVideoPreviewUrls.isNotEmpty
        ? profile.pendingVideoPreviewUrls
        : profile.videoPreviewUrls;
    final name = profile.fullName.trim().isEmpty
        ? profile.id
        : profile.fullName.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(kCardRadius),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: catalogCardDecoration().copyWith(
          border: Border.all(
            color: selected
                ? BrandTheme.redTop.withValues(alpha: 0.58)
                : Colors.white.withValues(alpha: 0.78),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            _ModerationMediaStrip(
              photoUrls: previewPhotos,
              videoUrls: previewVideos,
              videoPreviewUrls: previewVideoThumbs,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: adminCommandStyle(size: 17, letterSpacing: 0.7),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${profile.displayAge} • ${profile.height} cm',
                    style: adminBodyStyle(weight: FontWeight.w700),
                  ),
                  if (profile.hasPendingMedia) ...[
                    const SizedBox(height: 5),
                    Text(
                      'MEDIA UPDATE',
                      style: adminCommandStyle(
                        size: 10,
                        color: BrandTheme.redTop,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showInlineActions && profile.status == ProfileStatus.pending)
              Column(
                children: [
                  IconButton(
                    tooltip: approveTooltip,
                    icon: const Icon(Icons.check_circle_rounded),
                    color: kTextDark,
                    onPressed: onApprove,
                  ),
                  IconButton(
                    tooltip: rejectTooltip,
                    icon: const Icon(Icons.cancel_rounded),
                    color: kTextDark,
                    onPressed: onReject,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ModerationProfileDetailsPanel extends StatelessWidget {
  const _ModerationProfileDetailsPanel({
    required this.profile,
    required this.onApprove,
    required this.onReject,
  });

  final MyProfileState profile;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final media = _moderationMedia(profile);

    return Container(
      decoration: catalogCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ru ? 'АНКЕТА НА МОДЕРАЦИИ' : 'PROFILE REVIEW',
                    style: adminCommandStyle(size: 18, letterSpacing: 1.4),
                  ),
                ),
                if (profile.hasPendingMedia)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: BrandTheme.redTop.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: BrandTheme.redTop.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      ru ? 'НОВЫЕ МЕДИА' : 'NEW MEDIA',
                      style: adminCommandStyle(
                        size: 10,
                        color: BrandTheme.redTop,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _ModerationDesktopReviewBody(
                  profile: profile,
                  media: media,
                  twoColumn:
                      constraints.maxWidth >=
                      _moderationDesktopDetailBreakpoint,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: BrandTheme.pillHeight,
                    child: ElevatedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded),
                      label: Text(t.moderationRejectActionUpper),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: BrandTheme.pillHeight,
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(t.profileStatusApprovedUpper),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationDesktopReviewBody extends StatelessWidget {
  const _ModerationDesktopReviewBody({
    required this.profile,
    required this.media,
    required this.twoColumn,
  });

  final MyProfileState profile;
  final List<_ModerationMediaItem> media;
  final bool twoColumn;

  @override
  Widget build(BuildContext context) {
    if (!twoColumn) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        children: [
          _ModerationReviewMediaGallery(media: media, compact: true),
          const SizedBox(height: 22),
          _ModerationReviewProfileInfo(profile: profile),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 390,
            child: _ModerationReviewMediaGallery(media: media),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [_ModerationReviewProfileInfo(profile: profile)],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationReviewMediaGallery extends StatelessWidget {
  const _ModerationReviewMediaGallery({
    required this.media,
    this.compact = false,
  });

  final List<_ModerationMediaItem> media;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';

    if (media.isEmpty) {
      return Container(
        height: compact ? 240 : null,
        decoration: profileImagePlaceholderDecoration(),
      );
    }

    final primary = media.first;
    final rest = media.skip(1).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ru ? 'МЕДИА' : 'MEDIA',
          style: adminCommandStyle(size: 13, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: compact ? 260 : 360,
          child: _ModerationHeroMedia(
            item: primary,
            media: media,
            initialIndex: 0,
          ),
        ),
        if (primary.isCover) ...[
          const SizedBox(height: 12),
          _ModerationCoverHintLine(text: _moderationCoverHint(context)),
        ],
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: _moderationMediaSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rest.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => _ModerationMediaThumb(
                item: rest[index],
                media: media,
                initialIndex: index + 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModerationReviewProfileInfo extends StatelessWidget {
  const _ModerationReviewProfileInfo({required this.profile});

  final MyProfileState profile;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final name = profile.fullName.trim().isEmpty
        ? profile.id
        : profile.fullName.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: adminCommandStyle(size: 28, letterSpacing: 0.7)),
        const SizedBox(height: 8),
        Text(
          '${profile.displayAge} • ${profile.height} cm • ${profile.city} ${profile.country}',
          style: adminBodyStyle(weight: FontWeight.w800, size: 16),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ModerationMetricChip(
              label: ru ? 'Параметры' : 'Measurements',
              value: '${profile.bust} / ${profile.waist} / ${profile.hips}',
            ),
            _ModerationMetricChip(
              label: ru ? 'Обувь' : 'Shoes',
              value: '${profile.shoeSize}',
            ),
            _ModerationMetricChip(
              label: ru ? 'Глаза' : 'Eyes',
              value: profile.eyeColor,
            ),
            _ModerationMetricChip(
              label: ru ? 'Волосы' : 'Hair',
              value: profile.hairColor,
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (profile.resume.trim().isNotEmpty)
          _ModerationDetailLine(
            label: ru ? 'О себе' : 'About',
            value: profile.resume.trim(),
          ),
        if (profile.experience.trim().isNotEmpty)
          _ModerationDetailLine(
            label: ru ? 'Опыт' : 'Experience',
            value: profile.experience.trim(),
          ),
        if (profile.skills.trim().isNotEmpty)
          _ModerationDetailLine(
            label: ru ? 'Навыки' : 'Skills',
            value: profile.skills.trim(),
          ),
        if (profile.services.trim().isNotEmpty)
          _ModerationDetailLine(
            label: ru ? 'Услуги' : 'Services',
            value: profile.services.trim(),
          ),
        if (profile.genres.trim().isNotEmpty)
          _ModerationDetailLine(
            label: ru ? 'Жанры' : 'Genres',
            value: profile.genres.trim(),
          ),
        if (profile.equipment.trim().isNotEmpty)
          _ModerationDetailLine(
            label: ru ? 'Оборудование' : 'Equipment',
            value: profile.equipment.trim(),
          ),
      ],
    );
  }
}

class _ModerationMetricChip extends StatelessWidget {
  const _ModerationMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 126),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: catalogSearchDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: adminCommandStyle(size: 10, letterSpacing: 0.8)),
          const SizedBox(height: 5),
          Text(
            value.trim().isEmpty ? '—' : value.trim(),
            style: adminBodyStyle(weight: FontWeight.w800, size: 15),
          ),
        ],
      ),
    );
  }
}

List<_ModerationMediaItem> _moderationMedia(MyProfileState profile) {
  final photos = _photosWithCoverFirst(
    _mergeUniqueMedia(profile.photoUrls, profile.pendingPhotoUrls),
    profile.pendingCoverPhotoUrl.trim().isNotEmpty
        ? profile.pendingCoverPhotoUrl
        : profile.coverPhotoUrl,
  );
  final videos = _mergeUniqueMedia(profile.videoUrls, profile.pendingVideoUrls);
  final videoThumbs = _mergeUniqueMedia(
    profile.videoPreviewUrls,
    profile.pendingVideoPreviewUrls,
  );

  return <_ModerationMediaItem>[
    for (var i = 0; i < photos.length; i += 1)
      _ModerationMediaItem.photo(photos[i], isCover: i == 0),
    for (var i = 0; i < videos.length; i += 1)
      _ModerationMediaItem.video(
        videoUrl: videos[i],
        previewUrl: i < videoThumbs.length ? videoThumbs[i] : '',
      ),
  ];
}

class _ModerationDetailLine extends StatelessWidget {
  const _ModerationDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: adminCommandStyle(size: 12, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value, style: adminBodyStyle(weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ModerationHeroMedia extends StatelessWidget {
  const _ModerationHeroMedia({
    required this.item,
    required this.media,
    required this.initialIndex,
  });

  final _ModerationMediaItem item;
  final List<_ModerationMediaItem> media;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.isEmpty
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ModerationMediaViewerPage(
                  media: media,
                  initialIndex: initialIndex,
                ),
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.url.trim().isEmpty)
              Container(color: const Color(0xFFE5E5E5))
            else
              CachedNetworkImage(
                imageUrl: item.url,
                fit: BoxFit.cover,
                memCacheWidth: 900,
                maxWidthDiskCache: 1400,
                placeholder: (_, _) =>
                    Container(color: const Color(0xFFE5E5E5)),
                errorWidget: (_, _, _) =>
                    Container(color: const Color(0xFFE5E5E5)),
              ),
            if (item.isCover)
              _ModerationCoverBadge(
                label: _moderationCoverLabel(context),
                large: true,
              ),
            if (item.isVideo)
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x77000000),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModerationLargeMedia extends StatelessWidget {
  const _ModerationLargeMedia({
    required this.item,
    required this.media,
    required this.initialIndex,
  });

  final _ModerationMediaItem item;
  final List<_ModerationMediaItem> media;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.isEmpty
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ModerationMediaViewerPage(
                  media: media,
                  initialIndex: initialIndex,
                ),
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 170,
          height: 210,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.url.trim().isEmpty)
                Container(color: const Color(0xFFE5E5E5))
              else
                CachedNetworkImage(
                  imageUrl: item.url,
                  fit: BoxFit.cover,
                  memCacheWidth: 540,
                  maxWidthDiskCache: 900,
                ),
              if (item.isCover)
                _ModerationCoverBadge(
                  label: _moderationCoverLabel(context),
                  large: true,
                ),
              if (item.isVideo)
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x77000000),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModerationCoverBadge extends StatelessWidget {
  const _ModerationCoverBadge({required this.label, this.large = false});

  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: large ? 10 : 5,
      right: large ? 10 : 5,
      bottom: large ? 10 : 5,
      child: IgnorePointer(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: large ? 10 : 5,
            vertical: large ? 6 : 3,
          ),
          decoration: BoxDecoration(
            color: BrandTheme.redTop.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: large ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: large ? 10 : 7,
              fontWeight: FontWeight.w900,
              letterSpacing: large ? 0.9 : 0.5,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModerationCoverHintLine extends StatelessWidget {
  const _ModerationCoverHintLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: BrandTheme.redTop.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandTheme.redTop.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: BrandTheme.redTop, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: adminBodyStyle(
                weight: FontWeight.w800,
                size: 12,
                color: BrandTheme.redTop,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _commentC = TextEditingController();
  int? _selectedIndex;
  bool _showRequired = false;

  @override
  void dispose() {
    _commentC.dispose();
    super.dispose();
  }

  String _reason(List<String> reasons) {
    final custom = _commentC.text.trim();
    if (custom.isNotEmpty) return custom;

    final selected = _selectedIndex;
    if (selected == null) return '';
    return reasons[selected].trim();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final reasons = <String>[
      t.moderationRejectPoorPhotos,
      t.moderationRejectFaceNotVisible,
      t.moderationRejectIncompleteData,
      t.moderationRejectInvalidMedia,
      t.moderationRejectSuspicious,
    ];

    return AlertDialog(
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      title: Text(
        t.moderationRejectTitle,
        style: adminCommandStyle(size: 17, letterSpacing: 0.9),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < reasons.length; i += 1)
                ChoiceChip(
                  label: Text(reasons[i]),
                  selected: _selectedIndex == i,
                  selectedColor: BrandTheme.redTop.withValues(alpha: 0.14),
                  checkmarkColor: BrandTheme.redTop,
                  onSelected: (_) {
                    setState(() {
                      _selectedIndex = i;
                      _showRequired = false;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentC,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) {
              if (_showRequired) setState(() => _showRequired = false);
            },
            decoration: InputDecoration(
              hintText: t.moderationRejectHint,
              filled: true,
              fillColor: Colors.white,
              border: pillBorder(),
              enabledBorder: pillBorder(),
              focusedBorder: pillBorder(color: BrandTheme.redTop, width: 1.2),
              errorText: _showRequired ? t.moderationRejectRequired : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        TextButton(
          onPressed: () {
            final reason = _reason(reasons);
            if (reason.isEmpty) {
              setState(() => _showRequired = true);
              return;
            }
            Navigator.of(context).pop(reason);
          },
          child: Text(
            t.moderationRejectActionUpper,
            style: adminCommandStyle(
              size: 13,
              color: BrandTheme.redTop,
              letterSpacing: 0.9,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModerationMediaStrip extends StatelessWidget {
  const _ModerationMediaStrip({
    required this.photoUrls,
    required this.videoUrls,
    required this.videoPreviewUrls,
  });

  final List<String> photoUrls;
  final List<String> videoUrls;
  final List<String> videoPreviewUrls;

  @override
  Widget build(BuildContext context) {
    final media = <_ModerationMediaItem>[
      for (var i = 0; i < photoUrls.length; i += 1)
        _ModerationMediaItem.photo(photoUrls[i], isCover: i == 0),
      for (var i = 0; i < videoUrls.length; i += 1)
        _ModerationMediaItem.video(
          videoUrl: videoUrls[i],
          previewUrl: i < videoPreviewUrls.length ? videoPreviewUrls[i] : '',
        ),
    ];

    if (media.isEmpty) {
      return const _ModerationMediaThumb(item: _ModerationMediaItem.empty());
    }

    final visible = media.take(3).toList(growable: false);

    return SizedBox(
      width: visible.length == 1
          ? _moderationMediaSize
          : (_moderationMediaSize + 8) * visible.length - 8,
      height: _moderationMediaSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => _ModerationMediaThumb(
          item: visible[index],
          media: media,
          initialIndex: index,
        ),
      ),
    );
  }
}

class _ModerationMediaItem {
  const _ModerationMediaItem._({
    required this.url,
    required this.videoUrl,
    required this.isVideo,
    required this.isEmpty,
    required this.isCover,
  });

  const _ModerationMediaItem.empty()
    : this._(
        url: '',
        videoUrl: '',
        isVideo: false,
        isEmpty: true,
        isCover: false,
      );

  const _ModerationMediaItem.photo(String url, {bool isCover = false})
    : this._(
        url: url,
        videoUrl: '',
        isVideo: false,
        isEmpty: false,
        isCover: isCover,
      );

  const _ModerationMediaItem.video({
    required String videoUrl,
    required String previewUrl,
  }) : this._(
         url: previewUrl,
         videoUrl: videoUrl,
         isVideo: true,
         isEmpty: false,
         isCover: false,
       );

  final String url;
  final String videoUrl;
  final bool isVideo;
  final bool isEmpty;
  final bool isCover;
}

class _ModerationMediaViewerPage extends StatefulWidget {
  const _ModerationMediaViewerPage({
    required this.media,
    required this.initialIndex,
  });

  final List<_ModerationMediaItem> media;
  final int initialIndex;

  @override
  State<_ModerationMediaViewerPage> createState() =>
      _ModerationMediaViewerPageState();
}

class _ModerationMediaViewerPageState
    extends State<_ModerationMediaViewerPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.media.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.media.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (_, index) =>
                  _ModerationMediaViewerItem(item: widget.media[index]),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            if (total > 1)
              Positioned(
                top: 22,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.54),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.media[_index].isCover)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: BrandTheme.redTop.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _moderationCoverHint(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModerationMediaViewerItem extends StatelessWidget {
  const _ModerationMediaViewerItem({required this.item});

  final _ModerationMediaItem item;

  @override
  Widget build(BuildContext context) {
    if (item.isVideo) {
      return _ModerationVideoViewer(url: item.videoUrl);
    }

    final url = item.url.trim();
    return Center(
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: url.isEmpty
            ? const Icon(
                Icons.broken_image_rounded,
                color: Colors.white,
                size: 42,
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
      ),
    );
  }
}

class _ModerationVideoViewer extends StatefulWidget {
  const _ModerationVideoViewer({required this.url});

  final String url;

  @override
  State<_ModerationVideoViewer> createState() => _ModerationVideoViewerState();
}

class _ModerationVideoViewerState extends State<_ModerationVideoViewer> {
  VideoPlayerController? _controller;
  Future<void>? _init;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    final url = widget.url.trim();
    if (url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setLooping(true);
    _controller = controller;
    _init = controller.initialize().then((_) async {
      await controller.play();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await controller.play();
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final init = _init;
    if (controller == null || init == null) {
      return const Center(
        child: Icon(Icons.videocam_off_rounded, color: Colors.white, size: 44),
      );
    }

    return Center(
      child: FutureBuilder<void>(
        future: init,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              !controller.value.isInitialized) {
            return const CircularProgressIndicator(color: Colors.white);
          }

          return GestureDetector(
            onTap: _toggle,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 16 / 9
                      : controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
                if (!_playing)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x77000000),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ModerationMediaThumb extends StatelessWidget {
  const _ModerationMediaThumb({
    required this.item,
    this.media = const <_ModerationMediaItem>[],
    this.initialIndex = 0,
  });

  final _ModerationMediaItem item;
  final List<_ModerationMediaItem> media;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.isEmpty || media.isEmpty
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ModerationMediaViewerPage(
                  media: media,
                  initialIndex: initialIndex,
                ),
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_moderationMediaRadius),
        child: SizedBox(
          width: _moderationMediaSize,
          height: _moderationMediaSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.isEmpty || item.url.trim().isEmpty)
                Container(color: const Color(0xFFE5E5E5))
              else
                CachedNetworkImage(
                  imageUrl: item.url,
                  fit: BoxFit.cover,
                  memCacheWidth: _moderationMediaCacheWidth,
                  maxWidthDiskCache: _moderationMediaCacheWidth,
                  placeholder: (_, _) =>
                      Container(color: const Color(0xFFE5E5E5)),
                  errorWidget: (_, _, _) =>
                      Container(color: const Color(0xFFE5E5E5)),
                ),
              if (item.isVideo)
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              if (item.isCover)
                _ModerationCoverBadge(label: _moderationCoverLabel(context)),
            ],
          ),
        ),
      ),
    );
  }
}
