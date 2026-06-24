import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error_mapper.dart';
import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../core/roles_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import 'admin_style.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_model.dart';
import '../profile/profile_supabase_schema.dart';

const int _moderationMediaCacheWidth = 280;
const double _moderationMediaSize = 64;
const double _moderationMediaRadius = 16;

String _formatModerationCounts(Map<String, int>? counts, {required bool ru}) {
  if (counts == null) {
    return ru
        ? 'SQL profile_submission_moderation_fix.sql еще не применен или приложение использует старую схему.'
        : 'profile_submission_moderation_fix.sql is not applied yet, or the app is still using the old schema.';
  }

  final pending = counts['pending'] ?? 0;
  final draft = counts['draft'] ?? 0;
  final approved = counts['approved'] ?? 0;
  final rejected = counts['rejected'] ?? 0;
  final total = counts.values.fold<int>(0, (sum, value) => sum + value);

  if (ru) {
    return 'Статусы в базе: на модерации $pending, черновики $draft, одобрено $approved, отклонено $rejected, всего $total.';
  }
  return 'Database statuses: pending $pending, draft $draft, approved $approved, rejected $rejected, total $total.';
}

final pendingProfilesProvider =
    FutureProvider.autoDispose<List<MyProfileState>>((ref) async {
      ref.watch(authStateProvider);
      final sb = ref.read(supabaseProvider);

      Future<List<dynamic>> loadViaRpc() async {
        return await sb.rpc('pending_profiles_for_moderation');
      }

      Future<List<dynamic>> load({
        required bool includeVerification,
        required bool includePendingMedia,
      }) async {
        final query = sb
            .from(ProfileSupabaseSchema.table)
            .select(
              ProfileSupabaseSchema.selectModeration(
                includeVerification: includeVerification,
                includePendingMedia: includePendingMedia,
              ),
            );

        return query.eq('status', 'pending').limit(200);
      }

      List<dynamic> rows = const <dynamic>[];
      var includeVerification = true;
      var includePendingMedia = true;
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

          if (!missingVerification && !missingPendingMedia) rethrow;

          if (missingVerification) includeVerification = false;
          if (missingPendingMedia) includePendingMedia = false;
        }
      }

      return rows
          .map((row) => MyProfileState.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    });

final moderationStatusCountsProvider =
    FutureProvider.autoDispose<Map<String, int>?>((ref) async {
      ref.watch(authStateProvider);
      final sb = ref.read(supabaseProvider);

      try {
        final rows = await sb.rpc('profile_moderation_status_counts');
        final counts = <String, int>{};
        for (final row in rows as List) {
          final map = Map<String, dynamic>.from(row as Map);
          final status = map['status']?.toString().trim();
          final count = int.tryParse(map['count']?.toString() ?? '') ?? 0;
          if (status != null && status.isNotEmpty) {
            counts[status] = count;
          }
        }
        return counts;
      } on PostgrestException catch (e) {
        if (SupabaseCompat.isMissingRpc(
          e,
          'profile_moderation_status_counts',
        )) {
          return null;
        }
        rethrow;
      }
    });

class ModerationAdminPage extends ConsumerWidget {
  const ModerationAdminPage({super.key});

  Future<void> _approveProfile(
    WidgetRef ref, {
    required String profileId,
  }) async {
    final sb = ref.read(supabaseProvider);

    try {
      await sb.rpc(
        'admin_publish_profile',
        params: {'p_profile_id': profileId},
      );
    } on PostgrestException catch (e) {
      if (!SupabaseCompat.isMissingRpc(e, 'admin_publish_profile')) {
        rethrow;
      }
      await sb
          .from('profiles')
          .update(<String, dynamic>{
            'status': 'approved',
            'moderation_comment': null,
          })
          .eq('id', profileId);
    }

    ref.invalidate(pendingProfilesProvider);
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

    ref.invalidate(pendingProfilesProvider);
  }

  Future<String?> _askRejectReason(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _RejectReasonDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final isAdminAsync = ref.watch(isAdminProvider);

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
                              final countsAsync = ref.watch(
                                moderationStatusCountsProvider,
                              );
                              return countsAsync.when(
                                loading: () => AdminMessageCard(
                                  text: ru
                                      ? 'ЗАЯВОК НЕТ\n\nПроверяю статусы анкет...'
                                      : 'NO REQUESTS\n\nChecking profile statuses...',
                                ),
                                error: (e, _) => AdminMessageCard(
                                  text: ru
                                      ? 'ЗАЯВОК НЕТ\n\nНе удалось проверить статусы: ${AppErrorMapper.message(e, t)}'
                                      : 'NO REQUESTS\n\nCould not check statuses: ${AppErrorMapper.message(e, t)}',
                                  isError: true,
                                ),
                                data: (counts) {
                                  final details = _formatModerationCounts(
                                    counts,
                                    ru: ru,
                                  );
                                  return AdminMessageCard(
                                    text: ru
                                        ? 'ЗАЯВОК НЕТ\n\n$details'
                                        : 'NO REQUESTS\n\n$details',
                                  );
                                },
                              );
                            }

                            return ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final p = items[i];
                                final previewPhotos =
                                    p.pendingPhotoUrls.isNotEmpty
                                    ? p.pendingPhotoUrls
                                    : p.photoUrls;
                                final previewVideos =
                                    p.pendingVideoUrls.isNotEmpty
                                    ? p.pendingVideoUrls
                                    : p.videoUrls;
                                final previewVideoThumbs =
                                    p.pendingVideoPreviewUrls.isNotEmpty
                                    ? p.pendingVideoPreviewUrls
                                    : p.videoPreviewUrls;

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: catalogCardDecoration(),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (p.fullName.trim().isEmpty)
                                                  ? p.id
                                                  : p.fullName.trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: adminCommandStyle(
                                                size: 17,
                                                letterSpacing: 0.7,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${p.age} • ${p.height} cm',
                                              style: adminBodyStyle(
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        children: [
                                          if (p.status ==
                                              ProfileStatus.pending) ...[
                                            IconButton(
                                              tooltip:
                                                  t.profileStatusApprovedUpper,
                                              icon: const Icon(
                                                Icons.check_circle_rounded,
                                              ),
                                              color: kTextDark,
                                              onPressed: () async {
                                                try {
                                                  await _approveProfile(
                                                    ref,
                                                    profileId: p.id,
                                                  );
                                                } catch (e) {
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        AppErrorMapper.message(
                                                          e,
                                                          t,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                            IconButton(
                                              tooltip:
                                                  t.moderationRejectActionUpper,
                                              icon: const Icon(
                                                Icons.cancel_rounded,
                                              ),
                                              color: kTextDark,
                                              onPressed: () async {
                                                try {
                                                  final reason =
                                                      await _askRejectReason(
                                                        context,
                                                      );
                                                  if (!context.mounted ||
                                                      reason == null) {
                                                    return;
                                                  }
                                                  await _rejectProfile(
                                                    ref,
                                                    profileId: p.id,
                                                    reason: reason,
                                                  );
                                                } catch (e) {
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        AppErrorMapper.message(
                                                          e,
                                                          t,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
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
      for (final url in photoUrls) _ModerationMediaItem.photo(url),
      for (var i = 0; i < videoUrls.length; i += 1)
        _ModerationMediaItem.video(
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
        itemBuilder: (_, index) => _ModerationMediaThumb(item: visible[index]),
      ),
    );
  }
}

class _ModerationMediaItem {
  const _ModerationMediaItem._({
    required this.url,
    required this.isVideo,
    required this.isEmpty,
  });

  const _ModerationMediaItem.empty()
    : this._(url: '', isVideo: false, isEmpty: true);

  const _ModerationMediaItem.photo(String url)
    : this._(url: url, isVideo: false, isEmpty: false);

  const _ModerationMediaItem.video({required String previewUrl})
    : this._(url: previewUrl, isVideo: true, isEmpty: false);

  final String url;
  final bool isVideo;
  final bool isEmpty;
}

class _ModerationMediaThumb extends StatelessWidget {
  const _ModerationMediaThumb({required this.item});

  final _ModerationMediaItem item;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
          ],
        ),
      ),
    );
  }
}
