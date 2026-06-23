import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_controller.dart';
import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../selection/selection_export_item.dart';
import '../selection/selection_pdf_options.dart';
import '../selection/selection_pdf_options_dialog.dart';
import '../selection/selection_pdf_service.dart';

const _bg = BrandTheme.greyMid;
const _text = kTextDark;

final castingResponsesProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, castingId) async {
      ref.watch(authStateProvider);
      final sb = ref.read(supabaseProvider);

      Future<List<dynamic>> run(String select) {
        return sb
            .from('casting_responses')
            .select(select)
            .eq('casting_id', castingId)
            .order('created_at', ascending: false)
            .limit(400);
      }

      const profileSelect = '''
        created_at,
        profile:profiles(
          id,
          full_name,
          age,
          height,
          city,
          country,
          eye_color,
          hair_color,
          bust,
          waist,
          hips,
          shoe_size,
          min_hourly_rate,
          min_daily_fee,
          photo_urls
        )
        ''';

      late final List<dynamic> rows;
      try {
        rows = await run(profileSelect);
      } on PostgrestException catch (e) {
        final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
            .toLowerCase();
        if (!msg.contains('status')) rethrow;
        rows = await run(profileSelect.replaceFirst('status,', ''));
      }

      final items = rows
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final exportItems = items
          .map((row) => (row['profile'] as Map?) ?? const {})
          .map((profile) => Map<String, dynamic>.from(profile))
          .where(
            (profile) => (profile['id'] ?? '').toString().trim().isNotEmpty,
          )
          .map(SelectionExportItem.fromProfileMap)
          .toList(growable: false);

      return {'items': items, 'exportItems': exportItems};
    });

class SelectionCastingPage extends ConsumerWidget {
  const SelectionCastingPage({super.key, required this.castingId});

  final String castingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final res = ref.watch(castingResponsesProvider(castingId));

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: res.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: _CardPill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    '${t.errorUpper}: ${AppErrorMapper.message(e, t)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: _text,
                    ),
                  ),
                ),
              ),
            ),
            data: (data) {
              final items = List<Map<String, dynamic>>.from(
                data['items'] as List<dynamic>,
              );
              final exportItems = List<SelectionExportItem>.from(
                data['exportItems'] as List<dynamic>,
              );

              Future<void> openPdf() async {
                final options = await showDialog<SelectionPdfOptions>(
                  context: context,
                  barrierDismissible: true,
                  builder: (_) => const SelectionPdfOptionsDialog(),
                );
                if (options == null) return;

                final service = SelectionPdfService();
                await service.previewSelectionPdf(
                  title: t.responsesUpper,
                  items: exportItems,
                  options: options,
                );
              }

              return Column(
                children: [
                  BrandAdminHeader(
                    title: t.responsesUpper,
                    onBack: () => context.go(Routes.adminSelection),
                    sideWidth: 104,
                    trailing: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            ref.invalidate(castingResponsesProvider(castingId));
                          },
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: BrandTheme.redTop,
                          ),
                          splashRadius: 22,
                        ),
                        IconButton(
                          onPressed: exportItems.isEmpty ? null : openPdf,
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: BrandTheme.redTop,
                          ),
                          splashRadius: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: _CardPill(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                child: Text(
                                  t.noResponsesMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                    color: _text,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : _CardPill(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final row = items[i];
                                final profile = (row['profile'] as Map?) ?? {};
                                final name = (profile['full_name'] ?? '')
                                    .toString();
                                final city = (profile['city'] ?? '').toString();

                                final subtitleParts = <String>[];
                                final age = profile['age'];
                                final height = profile['height'];
                                if (age != null) {
                                  subtitleParts.add('${t.ageShort}: $age');
                                }
                                if (height != null) {
                                  subtitleParts.add(
                                    '${t.heightShort}: $height',
                                  );
                                }
                                if (city.isNotEmpty) subtitleParts.add(city);

                                final profileId = (profile['id'] ?? '')
                                    .toString();
                                final photoUrlsRaw = profile['photo_urls'];
                                final photoUrls = photoUrlsRaw is List
                                    ? photoUrlsRaw
                                          .map((e) => e.toString())
                                          .where((e) => e.trim().isNotEmpty)
                                          .toList()
                                    : <String>[];
                                final coverUrl = photoUrls.isNotEmpty
                                    ? photoUrls.first
                                    : '';

                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.white.withValues(alpha: 0.30),
                                    border: Border.all(
                                      color: kBorderColor,
                                      width: 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: profileId.isEmpty
                                        ? null
                                        : () => context.go(
                                            '${Routes.modelPrefix}$profileId?from=casting&castingId=$castingId',
                                          ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          _SelectionProfileThumb(url: coverUrl),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name.isNotEmpty
                                                      ? name
                                                      : t.profileUpper,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.4,
                                                    color: _text,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                if (subtitleParts
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    subtitleParts.join(' • '),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: kTextMuted,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: BrandTheme.redTop,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CardPill extends StatelessWidget {
  const _CardPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: BrandTheme.lightPillGradient,
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: child,
    );
  }
}

class _SelectionProfileThumb extends StatelessWidget {
  const _SelectionProfileThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url.trim().isEmpty
            ? Container(
                color: const Color(0x14000000),
                alignment: Alignment.center,
                child: const Icon(Icons.person, color: _text),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: 160,
                maxWidthDiskCache: 320,
                placeholder: (_, _) =>
                    Container(color: const Color(0x14000000)),
                errorWidget: (_, _, _) => Container(
                  color: const Color(0x14000000),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_rounded, color: _text),
                ),
              ),
      ),
    );
  }
}
