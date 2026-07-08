import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

import '../../core/admin_action_log_service.dart';
import '../../core/app_error_mapper.dart';
import '../../core/public_links.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../chat/chat_providers.dart';
import '../catalog/model_data.dart';
import '../selection/selection_export_item.dart';
import '../selection/selection_pdf_options.dart';
import '../selection/selection_pdf_options_dialog.dart';
import '../selection/selection_pdf_service.dart';
import '../selection/public_profile_access_link_service.dart';
import 'selection_client_feedback.dart';
import 'selection_providers.dart';
import 'selection_status.dart';

const _bg = BrandTheme.greyMid;
const _text = kTextDark;

final selectionProjectProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, selectionId) async {
      final sb = ref.read(supabaseProvider);

      Future<Map<String, dynamic>?> loadSelection({
        required bool includePublic,
        required bool includeStatus,
        required bool includeCampaign,
      }) async {
        final fields = [
          'id',
          'title',
          'created_at',
          if (includePublic) 'is_public',
          if (includeStatus) 'status',
          if (includeCampaign) 'client_name',
          if (includeCampaign) 'brand_name',
          if (includeCampaign) 'budget',
          if (includeCampaign) 'location',
          if (includeCampaign) 'project_dates',
          if (includeCampaign) 'project_roles',
        ].join(',');

        final row = await sb
            .from('selections')
            .select(fields)
            .eq('id', selectionId)
            .maybeSingle();
        if (row == null) return null;
        return Map<String, dynamic>.from(row);
      }

      Map<String, dynamic>? selectionRow;
      try {
        selectionRow = await loadSelection(
          includePublic: true,
          includeStatus: true,
          includeCampaign: true,
        );
      } catch (_) {
        try {
          selectionRow = await loadSelection(
            includePublic: true,
            includeStatus: false,
            includeCampaign: true,
          );
        } catch (_) {
          try {
            selectionRow = await loadSelection(
              includePublic: false,
              includeStatus: false,
              includeCampaign: true,
            );
          } catch (_) {
            selectionRow = await loadSelection(
              includePublic: false,
              includeStatus: false,
              includeCampaign: false,
            );
          }
        }
      }

      final itemsRows = await sb
          .from('selection_items')
          .select('''
        created_at,
        profile:profiles(
          id,
          user_id,
          full_name,
          birth_date,
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
          cover_photo_url,
          photo_urls
        )
        ''')
          .eq('selection_id', selectionId)
          .order('created_at', ascending: false)
          .limit(400);

      final items = (itemsRows as List)
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

      return {
        'selection': selectionRow ?? const <String, dynamic>{},
        'items': items,
        'exportItems': exportItems,
      };
    });

Map<String, _AgentFeedbackSummary> _agentFeedbackSummaries(
  List<SelectionClientFeedback> feedback,
) {
  final result = <String, _AgentFeedbackSummary>{};

  for (final item in feedback) {
    final profileId = item.profileId.trim();
    if (profileId.isEmpty) continue;

    final summary = result.putIfAbsent(
      profileId,
      () => _AgentFeedbackSummary.empty(),
    );
    summary.add(item);
  }

  return result;
}

List<MapEntry<String, String>> _campaignRows(
  AppLocalizations t,
  Map<String, dynamic> selection,
) {
  String text(String key) => (selection[key] ?? '').toString().trim();
  final rows = <MapEntry<String, String>>[
    MapEntry(t.projectClient, text('client_name')),
    MapEntry(t.projectBrand, text('brand_name')),
    MapEntry(t.projectBudget, text('budget')),
    MapEntry(t.projectLocation, text('location')),
    MapEntry(t.projectDates, text('project_dates')),
    MapEntry(t.projectRoles, text('project_roles')),
  ];
  return rows.where((row) => row.value.isNotEmpty).toList(growable: false);
}

class SelectionProjectPage extends ConsumerWidget {
  const SelectionProjectPage({
    super.key,
    required this.selectionId,
    this.isPublic = false,
  });

  final String selectionId;
  final bool isPublic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final dataAsync = ref.watch(selectionProjectProvider(selectionId));

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: dataAsync.when(
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
              final selection = Map<String, dynamic>.from(
                data['selection'] as Map<String, dynamic>,
              );
              final items = List<Map<String, dynamic>>.from(
                data['items'] as List<dynamic>,
              );
              final exportItems = List<SelectionExportItem>.from(
                data['exportItems'] as List<dynamic>,
              );
              final title = (selection['title'] ?? '').toString();
              final publicEnabled = selection['is_public'] == true;
              final status = selectionStatusFromString(selection['status']);
              final publicLink = publicSelectionLink(selectionId);
              final campaignRows = _campaignRows(t, selection);

              final clientKey = isPublic
                  ? ref.watch(selectionClientKeyProvider).valueOrNull ?? ''
                  : '';
              final clientFeedback = isPublic && clientKey.isNotEmpty
                  ? ref
                            .watch(
                              selectionClientFeedbackProvider(
                                SelectionClientFeedbackRequest(
                                  selectionId: selectionId,
                                  clientKey: clientKey,
                                ),
                              ),
                            )
                            .valueOrNull ??
                        const <String, SelectionClientFeedback>{}
                  : const <String, SelectionClientFeedback>{};
              final agentFeedback = !isPublic
                  ? ref
                            .watch(selectionAgentFeedbackProvider(selectionId))
                            .valueOrNull ??
                        const <SelectionClientFeedback>[]
                  : const <SelectionClientFeedback>[];
              final agentFeedbackByProfile = _agentFeedbackSummaries(
                agentFeedback,
              );

              if (isPublic && !publicEnabled) {
                return Center(
                  child: _CardPill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        t.publicSelectionUnavailable,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: _text,
                        ),
                      ),
                    ),
                  ),
                );
              }

              Future<void> openPdf() async {
                final options = await showDialog<SelectionPdfOptions>(
                  context: context,
                  barrierDismissible: true,
                  builder: (_) => const SelectionPdfOptionsDialog(),
                );
                if (options == null) return;

                final modelLinks =
                    await PublicProfileAccessLinkService(
                      ref.read(supabaseProvider),
                    ).createLinks(
                      profileIds: exportItems.map((e) => e.id),
                      source: 'selection_pdf',
                      relatedId: selectionId,
                    );
                final service = SelectionPdfService();
                await service.previewSelectionPdf(
                  title: title.isNotEmpty ? title : t.selectionUpper,
                  items: exportItems,
                  options: options,
                  modelLinks: modelLinks,
                );
              }

              Future<void> setStatus(SelectionStatus next) async {
                try {
                  final sb = ref.read(supabaseProvider);
                  try {
                    await sb.rpc(
                      'set_selection_status',
                      params: {
                        'p_selection_id': selectionId,
                        'p_status': next.storageValue,
                      },
                    );
                  } catch (_) {
                    await sb
                        .from('selections')
                        .update({'status': next.storageValue})
                        .eq('id', selectionId);
                  }
                  await AdminActionLogService(sb).log(
                    actionType: 'selection_status_changed',
                    title: 'Статус подборки изменен',
                    description: selectionStatusLabel(t, next),
                    targetTable: 'selections',
                    targetId: selectionId,
                    targetText: title,
                    status: next.storageValue,
                    metadata: {
                      'selection_id': selectionId,
                      'selection_title': title,
                      'previous_status': status.storageValue,
                      'next_status': next.storageValue,
                    },
                  );
                  ref.invalidate(selectionProjectProvider(selectionId));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          '${t.errorUpper}: ${AppErrorMapper.message(e, t)}',
                        ),
                      ),
                    );
                }
              }

              Future<void> setPublic(bool next) async {
                try {
                  final sb = ref.read(supabaseProvider);
                  try {
                    await sb.rpc(
                      'set_selection_public',
                      params: {
                        'p_selection_id': selectionId,
                        'p_is_public': next,
                      },
                    );
                  } catch (_) {
                    await sb
                        .from('selections')
                        .update({
                          'is_public': next,
                          if (next && status == SelectionStatus.draft)
                            'status': SelectionStatus.sentToClient.storageValue,
                        })
                        .eq('id', selectionId);
                  }
                  await AdminActionLogService(sb).log(
                    actionType: next
                        ? 'selection_public_link_enabled'
                        : 'selection_public_link_disabled',
                    title: next
                        ? 'Публичная ссылка подборки включена'
                        : 'Публичная ссылка подборки выключена',
                    description: publicLink,
                    targetTable: 'selections',
                    targetId: selectionId,
                    targetText: title,
                    status: next ? 'public' : 'private',
                    metadata: {
                      'selection_id': selectionId,
                      'selection_title': title,
                      'public_link': publicLink,
                      'is_public': next,
                    },
                  );
                  ref.invalidate(selectionProjectProvider(selectionId));
                  ref.invalidate(adminSelectionListProvider);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          '${t.errorUpper}: ${AppErrorMapper.message(e, t)}',
                        ),
                      ),
                    );
                }
              }

              Future<void> copyPublicLink() async {
                await Clipboard.setData(ClipboardData(text: publicLink));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(t.publicSelectionLinkCopied)),
                  );
              }

              if (isPublic &&
                  publicEnabled &&
                  status == SelectionStatus.sentToClient) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    await ref
                        .read(supabaseProvider)
                        .rpc(
                          'mark_selection_client_viewed',
                          params: {'p_selection_id': selectionId},
                        );
                    ref.invalidate(selectionProjectProvider(selectionId));
                  } catch (_) {
                    // Public status tracking is optional until SQL is applied.
                  }
                });
              }

              return Column(
                children: [
                  BrandAdminHeader(
                    title: title.isNotEmpty ? title : t.selectionUpper,
                    onBack: isPublic
                        ? () => context.go(Routes.search)
                        : () => context.go(Routes.adminSelection),
                    trailing: isPublic
                        ? null
                        : IconButton(
                            onPressed: exportItems.isEmpty ? null : openPdf,
                            splashRadius: 22,
                            tooltip: 'PDF',
                            icon: Icon(
                              Icons.picture_as_pdf_rounded,
                              color: exportItems.isEmpty
                                  ? kTextMuted
                                  : BrandTheme.redTop,
                            ),
                          ),
                  ),
                  if (isPublic) ...[
                    const SizedBox(height: 12),
                    const _PublicClientIntro(),
                  ],
                  const SizedBox(height: 12),
                  if (!isPublic) ...[
                    if (campaignRows.isNotEmpty) ...[
                      _CampaignInfoPanel(rows: campaignRows),
                      const SizedBox(height: 12),
                    ],
                    _SelectionStatusPanel(status: status, onChanged: setStatus),
                    const SizedBox(height: 12),
                    _PublicSelectionPanel(
                      enabled: publicEnabled,
                      link: publicLink,
                      onToggle: setPublic,
                      onCopy: copyPublicLink,
                    ),
                    const SizedBox(height: 12),
                  ],
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
                                final age = ModelVm.displayAgeFromMap(
                                  Map<String, dynamic>.from(profile),
                                );
                                final height = profile['height'];
                                if (age > 0) {
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
                                final modelUserId = (profile['user_id'] ?? '')
                                    .toString();
                                final photoUrlsRaw = profile['photo_urls'];
                                final photoUrls = photoUrlsRaw is List
                                    ? photoUrlsRaw
                                          .map((e) => e.toString())
                                          .where((e) => e.trim().isNotEmpty)
                                          .toList()
                                    : <String>[];
                                final coverUrl =
                                    (profile['cover_photo_url'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty
                                    ? (profile['cover_photo_url'] ?? '')
                                          .toString()
                                          .trim()
                                    : (photoUrls.isNotEmpty
                                          ? photoUrls.first
                                          : '');

                                return _SelectionProfileCard(
                                  selectionId: selectionId,
                                  profileId: profileId,
                                  modelUserId: modelUserId,
                                  clientKey: clientKey,
                                  clientFeedback: clientFeedback[profileId],
                                  agentFeedback:
                                      agentFeedbackByProfile[profileId],
                                  isPublic: isPublic,
                                  name: name.isNotEmpty ? name : t.profileUpper,
                                  subtitle: subtitleParts.join(' • '),
                                  coverUrl: coverUrl,
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

class _SelectionChatButton extends ConsumerStatefulWidget {
  const _SelectionChatButton({
    required this.selectionId,
    required this.profileId,
    required this.modelUserId,
  });

  final String selectionId;
  final String profileId;
  final String modelUserId;

  @override
  ConsumerState<_SelectionChatButton> createState() =>
      _SelectionChatButtonState();
}

class _SelectionChatButtonState extends ConsumerState<_SelectionChatButton> {
  bool _busy = false;

  Future<void> _openChat() async {
    if (_busy ||
        widget.selectionId.isEmpty ||
        widget.profileId.isEmpty ||
        widget.modelUserId.isEmpty) {
      return;
    }

    setState(() => _busy = true);
    try {
      final chatId = await ref
          .read(chatServiceProvider)
          .ensureSelectionChat(
            selectionId: widget.selectionId,
            profileId: widget.profileId,
            modelUserId: widget.modelUserId,
          );
      if (!mounted || chatId.isEmpty) return;
      context.push('${Routes.chatPrefix}$chatId');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _busy ? null : _openChat,
      tooltip: AppLocalizations.of(context)!.openChatUpper,
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chat_bubble_rounded, color: BrandTheme.redTop),
    );
  }
}

class _AgentFeedbackSummary {
  _AgentFeedbackSummary({
    required this.likes,
    required this.rejects,
    required this.comments,
  });

  factory _AgentFeedbackSummary.empty() {
    return _AgentFeedbackSummary(likes: 0, rejects: 0, comments: <String>[]);
  }

  int likes;
  int rejects;
  final List<String> comments;

  void add(SelectionClientFeedback feedback) {
    switch (feedback.vote) {
      case SelectionClientVote.liked:
        likes += 1;
      case SelectionClientVote.rejected:
        rejects += 1;
      case null:
        break;
    }

    final comment = feedback.comment.trim();
    if (comment.isNotEmpty) comments.add(comment);
  }

  bool get isEmpty => likes == 0 && rejects == 0 && comments.isEmpty;
}

class _SelectionProfileCard extends StatelessWidget {
  const _SelectionProfileCard({
    required this.selectionId,
    required this.profileId,
    required this.modelUserId,
    required this.clientKey,
    required this.clientFeedback,
    required this.agentFeedback,
    required this.isPublic,
    required this.name,
    required this.subtitle,
    required this.coverUrl,
  });

  final String selectionId;
  final String profileId;
  final String modelUserId;
  final String clientKey;
  final SelectionClientFeedback? clientFeedback;
  final _AgentFeedbackSummary? agentFeedback;
  final bool isPublic;
  final String name;
  final String subtitle;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.30),
        border: Border.all(color: kBorderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            leading: _SelectionProfileThumb(url: coverUrl),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: _text,
              ),
            ),
            subtitle: subtitle.isEmpty ? null : Text(subtitle),
            trailing: isPublic
                ? const Icon(Icons.chevron_right, color: BrandTheme.redTop)
                : _SelectionChatButton(
                    selectionId: selectionId,
                    profileId: profileId,
                    modelUserId: modelUserId,
                  ),
            onTap: profileId.isEmpty
                ? null
                : () => context.go(
                    isPublic
                        ? '${Routes.publicModelPrefix}$profileId'
                        : '${Routes.modelPrefix}$profileId?from=project&selectionId=$selectionId',
                  ),
          ),
          if (isPublic)
            _ClientFeedbackControls(
              selectionId: selectionId,
              profileId: profileId,
              clientKey: clientKey,
              initial: clientFeedback,
            )
          else if (agentFeedback != null && !agentFeedback!.isEmpty)
            _AgentFeedbackView(summary: agentFeedback!)
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                t.clientFeedbackEmpty,
                style: const TextStyle(
                  color: kTextMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClientFeedbackControls extends ConsumerStatefulWidget {
  const _ClientFeedbackControls({
    required this.selectionId,
    required this.profileId,
    required this.clientKey,
    required this.initial,
  });

  final String selectionId;
  final String profileId;
  final String clientKey;
  final SelectionClientFeedback? initial;

  @override
  ConsumerState<_ClientFeedbackControls> createState() =>
      _ClientFeedbackControlsState();
}

class _ClientFeedbackControlsState
    extends ConsumerState<_ClientFeedbackControls> {
  late final TextEditingController _commentC;
  SelectionClientVote? _vote;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _vote = widget.initial?.vote;
    _commentC = TextEditingController(text: widget.initial?.comment ?? '');
  }

  @override
  void didUpdateWidget(covariant _ClientFeedbackControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial == widget.initial) return;
    _vote = widget.initial?.vote;
    final nextComment = widget.initial?.comment ?? '';
    if (_commentC.text != nextComment) {
      _commentC.text = nextComment;
    }
  }

  @override
  void dispose() {
    _commentC.dispose();
    super.dispose();
  }

  Future<void> _save({SelectionClientVote? vote}) async {
    if (_saving || widget.clientKey.isEmpty) return;

    final nextVote = vote ?? _vote;
    setState(() {
      _saving = true;
      _vote = nextVote;
    });

    final t = AppLocalizations.of(context)!;
    try {
      await ref
          .read(selectionClientFeedbackServiceProvider)
          .saveFeedback(
            selectionId: widget.selectionId,
            profileId: widget.profileId,
            clientKey: widget.clientKey,
            vote: nextVote,
            comment: _commentC.text,
          );
      ref.invalidate(
        selectionClientFeedbackProvider(
          SelectionClientFeedbackRequest(
            selectionId: widget.selectionId,
            clientKey: widget.clientKey,
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.clientFeedbackSaved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${t.errorUpper}: ${AppErrorMapper.message(e, t)}'),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _FeedbackVoteButton(
                  label: t.clientFeedbackLike,
                  icon: Icons.thumb_up_alt_rounded,
                  selected: _vote == SelectionClientVote.liked,
                  onTap: () => _save(vote: SelectionClientVote.liked),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FeedbackVoteButton(
                  label: t.clientFeedbackReject,
                  icon: Icons.thumb_down_alt_rounded,
                  selected: _vote == SelectionClientVote.rejected,
                  onTap: () => _save(vote: SelectionClientVote.rejected),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _commentC,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(color: _text),
            decoration: pillInputDecoration(hint: t.clientFeedbackCommentHint),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _saving ? null : () => _save(),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(t.clientFeedbackSaveComment),
              style: TextButton.styleFrom(
                foregroundColor: BrandTheme.redTop,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackVoteButton extends StatelessWidget {
  const _FeedbackVoteButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: pillDecoration(isDark: selected, radius: 999).copyWith(
            border: Border.all(
              color: selected ? Colors.transparent : kBorderColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : BrandTheme.redTop,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
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

class _AgentFeedbackView extends StatelessWidget {
  const _AgentFeedbackView({required this.summary});

  final _AgentFeedbackSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AgentFeedbackPill(
                icon: Icons.thumb_up_alt_rounded,
                text: t.clientFeedbackLikesCount(summary.likes),
              ),
              _AgentFeedbackPill(
                icon: Icons.thumb_down_alt_rounded,
                text: t.clientFeedbackRejectsCount(summary.rejects),
              ),
            ],
          ),
          for (final comment in summary.comments.take(3)) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentFeedbackPill extends StatelessWidget {
  const _AgentFeedbackPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pillDecoration(
        isDark: false,
        radius: 999,
      ).copyWith(border: Border.all(color: kBorderColor)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: BrandTheme.redTop, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
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

class _CampaignInfoPanel extends StatelessWidget {
  const _CampaignInfoPanel({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _CardPill(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.projectCampaignUpper,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: _text,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            Text(
              row.key,
              style: const TextStyle(
                color: kTextMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              row.value,
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            if (row != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PublicClientIntro extends StatelessWidget {
  const _PublicClientIntro();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return _CardPill(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.publicSelectionClientTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.publicSelectionClientSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kTextMuted,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicSelectionPanel extends StatelessWidget {
  const _PublicSelectionPanel({
    required this.enabled,
    required this.link,
    required this.onToggle,
    required this.onCopy,
  });

  final bool enabled;
  final String link;
  final ValueChanged<bool> onToggle;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return _CardPill(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.publicSelectionLinkUpper,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: BrandTheme.redTop,
                onChanged: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            link,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kTextMuted,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PanelButton(
                  label: enabled
                      ? t.publicSelectionDisable
                      : t.publicSelectionEnable,
                  icon: enabled
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  isDark: false,
                  onTap: () => onToggle(!enabled),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PanelButton(
                  label: t.publicSelectionCopyLink,
                  icon: Icons.copy_rounded,
                  isDark: true,
                  onTap: enabled ? onCopy : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: pillDecoration(
              isDark: isDark,
              radius: 999,
            ).copyWith(border: Border.all(color: kBorderColor)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isDark ? Colors.white : BrandTheme.redTop,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : _text,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionStatusPanel extends StatelessWidget {
  const _SelectionStatusPanel({required this.status, required this.onChanged});

  final SelectionStatus status;
  final ValueChanged<SelectionStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return _CardPill(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.selectionStatusUpper,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in SelectionStatus.values)
                _SelectionStatusChip(
                  status: item,
                  selected: item == status,
                  onTap: () => onChanged(item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectionStatusChip extends StatelessWidget {
  const _SelectionStatusChip({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final SelectionStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final color = selectionStatusColor(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: selected ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            selectionStatusLabel(t, status),
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              fontSize: 12,
            ),
          ),
        ),
      ),
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
