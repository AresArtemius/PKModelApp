import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

import '../../core/admin_action_log_service.dart';
import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../core/supabase_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_logo.dart';
import '../../ui/brand/brand_pill_button.dart';
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
          'created_by',
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

      Future<Map<String, dynamic>> loadManager(String userId) async {
        final id = userId.trim();
        if (id.isEmpty) return const <String, dynamic>{};

        Future<Map<String, dynamic>> query(String columns) async {
          final row = await sb
              .from('user_profiles')
              .select(columns)
              .eq('user_id', id)
              .maybeSingle();
          return Map<String, dynamic>.from(row ?? const <String, dynamic>{});
        }

        try {
          return await query(
            'full_name,company_name,position,email,phone,account_tag,avatar_url,website,social_url',
          );
        } catch (_) {
          try {
            return await query('full_name,company_name,email,phone');
          } catch (_) {
            return const <String, dynamic>{};
          }
        }
      }

      final managerRow = await loadManager(
        (selectionRow?['created_by'] ?? '').toString(),
      );

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
        'manager': managerRow,
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
    this.from,
  });

  final String selectionId;
  final bool isPublic;
  final String? from;

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
                        : () => context.go(
                            from == 'admin_selections_table'
                                ? Routes.adminSelectionsTable
                                : Routes.adminSelection,
                          ),
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
                  const SizedBox(height: 12),
                  if (!isPublic) ...[
                    if (campaignRows.isNotEmpty) ...[
                      _CampaignInfoPanel(rows: campaignRows),
                      const SizedBox(height: 12),
                    ],
                    _SelectionStatusPanel(status: status, onChanged: setStatus),
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
                                final vm = _selectionProfileVmFromRow(
                                  context,
                                  items[i],
                                );
                                return _SelectionProfileCard(
                                  selectionId: selectionId,
                                  profileId: vm.profileId,
                                  modelUserId: vm.modelUserId,
                                  clientKey: clientKey,
                                  clientFeedback: clientFeedback[vm.profileId],
                                  agentFeedback:
                                      agentFeedbackByProfile[vm.profileId],
                                  isPublic: isPublic,
                                  name: vm.name,
                                  subtitle: vm.subtitle,
                                  coverUrl: vm.coverUrl,
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
    required this.selected,
    required this.reserve,
    required this.rejects,
    required this.comments,
  });

  factory _AgentFeedbackSummary.empty() {
    return _AgentFeedbackSummary(
      selected: 0,
      reserve: 0,
      rejects: 0,
      comments: <String>[],
    );
  }

  int selected;
  int reserve;
  int rejects;
  final List<String> comments;

  void add(SelectionClientFeedback feedback) {
    switch (feedback.vote) {
      case SelectionClientVote.selected:
        selected += 1;
      case SelectionClientVote.reserve:
        reserve += 1;
      case SelectionClientVote.rejected:
        rejects += 1;
      case null:
        break;
    }

    final comment = feedback.comment.trim();
    if (comment.isNotEmpty) comments.add(comment);
  }

  bool get isEmpty =>
      selected == 0 && reserve == 0 && rejects == 0 && comments.isEmpty;
}

class _SelectionPresentationProfile {
  const _SelectionPresentationProfile({
    required this.profileId,
    required this.modelUserId,
    required this.name,
    required this.subtitle,
    required this.city,
    required this.coverUrl,
    required this.photoUrls,
    required this.age,
    required this.height,
  });

  final String profileId;
  final String modelUserId;
  final String name;
  final String subtitle;
  final String city;
  final String coverUrl;
  final List<String> photoUrls;
  final int age;
  final int height;
}

_SelectionPresentationProfile _selectionProfileVmFromRow(
  BuildContext context,
  Map<String, dynamic> row,
) {
  final t = AppLocalizations.of(context)!;
  final profile = Map<String, dynamic>.from((row['profile'] as Map?) ?? {});
  final name = (profile['full_name'] ?? '').toString().trim();
  final city = (profile['city'] ?? '').toString().trim();
  final age = ModelVm.displayAgeFromMap(profile);
  final height = int.tryParse((profile['height'] ?? '').toString()) ?? 0;
  final subtitleParts = <String>[];
  if (age > 0) subtitleParts.add('${t.ageShort}: $age');
  if (height > 0) subtitleParts.add('${t.heightShort}: $height');
  if (city.isNotEmpty) subtitleParts.add(city);

  final photoUrlsRaw = profile['photo_urls'];
  final photoUrls = photoUrlsRaw is List
      ? photoUrlsRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
      : <String>[];
  final coverPhoto = (profile['cover_photo_url'] ?? '').toString().trim();
  final coverUrl = coverPhoto.isNotEmpty
      ? coverPhoto
      : (photoUrls.isNotEmpty ? photoUrls.first : '');

  return _SelectionPresentationProfile(
    profileId: (profile['id'] ?? '').toString().trim(),
    modelUserId: (profile['user_id'] ?? '').toString().trim(),
    name: name.isNotEmpty ? name : t.profileUpper,
    subtitle: subtitleParts.join(' • '),
    city: city,
    coverUrl: coverUrl,
    photoUrls: [
      if (coverUrl.isNotEmpty) coverUrl,
      ...photoUrls.where((e) => e != coverUrl),
    ],
    age: age,
    height: height,
  );
}

// Prototype kept for a possible future client presentation page. The active
// selection flow currently uses the compact list plus PDF export.
class _PublicSelectionPresentationView extends StatefulWidget {
  const _PublicSelectionPresentationView({
    required this.selectionId,
    required this.title,
    required this.selection,
    required this.campaignRows,
    required this.manager,
    required this.publicLink,
    required this.items,
    required this.clientKey,
    required this.clientFeedback,
  });

  final String selectionId;
  final String title;
  final Map<String, dynamic> selection;
  final List<MapEntry<String, String>> campaignRows;
  final Map<String, dynamic> manager;
  final String publicLink;
  final List<Map<String, dynamic>> items;
  final String clientKey;
  final Map<String, SelectionClientFeedback> clientFeedback;

  @override
  State<_PublicSelectionPresentationView> createState() =>
      _PublicSelectionPresentationViewState();
}

class _PublicSelectionPresentationViewState
    extends State<_PublicSelectionPresentationView> {
  int _selectedIndex = 0;

  Future<void> _copyPublicLink() async {
    await Clipboard.setData(ClipboardData(text: widget.publicLink));
    if (!mounted) return;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isRu ? 'Ссылка на подборку скопирована' : 'Selection link copied',
          ),
        ),
      );
  }

  @override
  void didUpdateWidget(covariant _PublicSelectionPresentationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.items.length) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.items
        .map((e) => _selectionProfileVmFromRow(context, e))
        .where((e) => e.profileId.isNotEmpty)
        .toList(growable: false);
    if (profiles.isEmpty) {
      return const SizedBox.shrink();
    }
    final selected = profiles[_selectedIndex.clamp(0, profiles.length - 1)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;
        final content = desktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 360,
                    child: _PublicSelectionRail(
                      profiles: profiles,
                      selectedIndex: _selectedIndex,
                      feedback: widget.clientFeedback,
                      onSelect: (index) => setState(() {
                        _selectedIndex = index;
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _PublicSelectionFeaturedProfile(
                      selectionId: widget.selectionId,
                      profile: selected,
                      clientKey: widget.clientKey,
                      feedback: widget.clientFeedback[selected.profileId],
                    ),
                  ),
                ],
              )
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _PublicSelectionFeaturedProfile(
                    selectionId: widget.selectionId,
                    profile: selected,
                    clientKey: widget.clientKey,
                    feedback: widget.clientFeedback[selected.profileId],
                  ),
                  const SizedBox(height: 12),
                  _PublicSelectionRail(
                    profiles: profiles,
                    selectedIndex: _selectedIndex,
                    feedback: widget.clientFeedback,
                    onSelect: (index) => setState(() {
                      _selectedIndex = index;
                    }),
                  ),
                ],
              );

        return Column(
          children: [
            _PublicPresentationHero(
              title: widget.title,
              count: profiles.length,
              feedback: widget.clientFeedback,
              selection: widget.selection,
              campaignRows: widget.campaignRows,
              manager: widget.manager,
              publicLink: widget.publicLink,
              onShare: _copyPublicLink,
            ),
            const SizedBox(height: 12),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

class _PublicPresentationHero extends StatelessWidget {
  const _PublicPresentationHero({
    required this.title,
    required this.count,
    required this.feedback,
    required this.selection,
    required this.campaignRows,
    required this.manager,
    required this.publicLink,
    required this.onShare,
  });

  final String title;
  final int count;
  final Map<String, SelectionClientFeedback> feedback;
  final Map<String, dynamic> selection;
  final List<MapEntry<String, String>> campaignRows;
  final Map<String, dynamic> manager;
  final String publicLink;
  final VoidCallback onShare;

  String _value(Map<String, dynamic> map, String key) {
    return (map[key] ?? '').toString().trim();
  }

  String _managerName(bool isRu) {
    final fullName = _value(manager, 'full_name');
    if (fullName.isNotEmpty) return fullName;
    final company = _value(manager, 'company_name');
    if (company.isNotEmpty) return company;
    return isRu ? 'PK Management' : 'PK Management';
  }

  String _managerSubtitle(bool isRu) {
    final parts = <String>[
      _value(manager, 'position'),
      _value(manager, 'company_name'),
    ].where((e) => e.isNotEmpty).toList(growable: false);
    if (parts.isNotEmpty) return parts.join(' • ');
    return isRu ? 'Менеджер подборки' : 'Selection manager';
  }

  List<String> _managerContacts() {
    return [
      _value(manager, 'phone'),
      _value(manager, 'email'),
      _value(manager, 'account_tag').isEmpty
          ? ''
          : '@${_value(manager, 'account_tag')}',
      _value(manager, 'website'),
      _value(manager, 'social_url'),
    ].where((e) => e.isNotEmpty).take(2).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final selected = feedback.values
        .where((e) => e.vote == SelectionClientVote.selected)
        .length;
    final reserve = feedback.values
        .where((e) => e.vote == SelectionClientVote.reserve)
        .length;
    final rejected = feedback.values
        .where((e) => e.vote == SelectionClientVote.rejected)
        .length;
    final brandName = _value(selection, 'brand_name');
    final clientName = _value(selection, 'client_name');
    final location = _value(selection, 'location');
    final dates = _value(selection, 'project_dates');
    final roles = _value(selection, 'project_roles');
    final managerContacts = _managerContacts();
    return _PresentationPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final stats = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PresentationStatPill(
                icon: Icons.groups_rounded,
                label: isRu ? 'Анкет' : 'Profiles',
                value: '$count',
              ),
              _PresentationStatPill(
                icon: Icons.check_circle_rounded,
                label: isRu ? 'Выбран' : 'Selected',
                value: '$selected',
              ),
              _PresentationStatPill(
                icon: Icons.bookmark_rounded,
                label: isRu ? 'Резерв' : 'Reserve',
                value: '$reserve',
              ),
              _PresentationStatPill(
                icon: Icons.block_rounded,
                label: isRu ? 'Отказ' : 'Rejected',
                value: '$rejected',
              ),
            ],
          );
          final projectChips = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (brandName.isNotEmpty)
                _PresentationInfoChip(
                  icon: Icons.business_center_rounded,
                  label: brandName,
                ),
              if (clientName.isNotEmpty)
                _PresentationInfoChip(
                  icon: Icons.handshake_rounded,
                  label: clientName,
                ),
              if (dates.isNotEmpty)
                _PresentationInfoChip(
                  icon: Icons.calendar_month_rounded,
                  label: dates,
                ),
              if (location.isNotEmpty)
                _PresentationInfoChip(
                  icon: Icons.location_on_rounded,
                  label: location,
                ),
              if (roles.isNotEmpty)
                _PresentationInfoChip(
                  icon: Icons.assignment_ind_rounded,
                  label: roles,
                ),
            ],
          );
          final copy = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  const BrandLogo(height: 54),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'PK MANAGEMENT',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 16,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: compact ? TextAlign.center : TextAlign.left,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 30,
                  height: 1.02,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isRu
                    ? 'Клиентская подборка моделей. Отметьте понравившихся, оставьте комментарии и отправьте ссылку команде.'
                    : 'Client model presentation. Mark favorites, leave comments, and share the link with your team.',
                textAlign: compact ? TextAlign.center : TextAlign.left,
                style: const TextStyle(
                  color: kTextMuted,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              if (projectChips.children.isNotEmpty) ...[
                const SizedBox(height: 12),
                projectChips,
              ],
            ],
          );
          final managerCard = _PublicDeliveryManagerCard(
            title: isRu ? 'Контакт менеджера' : 'Manager contact',
            name: _managerName(isRu),
            subtitle: _managerSubtitle(isRu),
            avatarUrl: _value(manager, 'avatar_url'),
            contacts: managerContacts,
            linkLabel: isRu ? 'Ссылка активна' : 'Link active',
            linkValue: isRu ? 'до выключения публикации' : 'until unpublished',
            publicLink: publicLink,
            onShare: onShare,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                copy,
                const SizedBox(height: 14),
                stats,
                const SizedBox(height: 12),
                managerCard,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 18),
              SizedBox(
                width: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [stats, const SizedBox(height: 12), managerCard],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PublicDeliveryManagerCard extends StatelessWidget {
  const _PublicDeliveryManagerCard({
    required this.title,
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
    required this.contacts,
    required this.linkLabel,
    required this.linkValue,
    required this.publicLink,
    required this.onShare,
  });

  final String title;
  final String name;
  final String subtitle;
  final String avatarUrl;
  final List<String> contacts;
  final String linkLabel;
  final String linkValue;
  final String publicLink;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: pillDecoration(isDark: false, radius: 20).copyWith(
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: kTextMuted,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: avatarUrl.trim().isEmpty
                    ? Container(
                        decoration: pillDecoration(isDark: true, radius: 16),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                        ),
                      )
                    : _PresentationImage(url: avatarUrl, radius: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (contacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final contact in contacts)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  contact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          _PresentationInfoChip(
            icon: Icons.verified_user_rounded,
            label: '$linkLabel: $linkValue',
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: BrandTheme.pillHeight,
            child: BrandPillButton(
              label: isRu ? 'ПОДЕЛИТЬСЯ' : 'SHARE',
              style: BrandPillStyle.dark,
              onTap: publicLink.trim().isEmpty ? null : onShare,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicSelectionFeaturedProfile extends StatelessWidget {
  const _PublicSelectionFeaturedProfile({
    required this.selectionId,
    required this.profile,
    required this.clientKey,
    required this.feedback,
  });

  final String selectionId;
  final _SelectionPresentationProfile profile;
  final String clientKey;
  final SelectionClientFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    return _PresentationPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 620;
          final gallery = _PublicProfileImageGallery(profile: profile);
          final details = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  profile.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    height: 1.04,
                  ),
                ),
                if (profile.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    profile.subtitle,
                    style: const TextStyle(
                      color: kTextMuted,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (profile.age > 0)
                      _PresentationInfoChip(
                        icon: Icons.cake_rounded,
                        label: isRu ? '${profile.age} лет' : '${profile.age}',
                      ),
                    if (profile.height > 0)
                      _PresentationInfoChip(
                        icon: Icons.straighten_rounded,
                        label: '${profile.height} см',
                      ),
                    if (profile.city.isNotEmpty)
                      _PresentationInfoChip(
                        icon: Icons.location_on_rounded,
                        label: profile.city,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: BrandPillButton(
                    label: isRu ? 'АНКЕТА' : 'PROFILE',
                    style: BrandPillStyle.dark,
                    onTap: profile.profileId.isEmpty
                        ? null
                        : () => context.go(
                            '${Routes.publicModelPrefix}${profile.profileId}',
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                _ClientFeedbackControls(
                  selectionId: selectionId,
                  profileId: profile.profileId,
                  clientKey: clientKey,
                  initial: feedback,
                ),
              ],
            ),
          );
          if (desktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 360, child: gallery),
                Expanded(child: details),
              ],
            );
          }
          return ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [gallery, details],
          );
        },
      ),
    );
  }
}

class _PublicProfileImageGallery extends StatelessWidget {
  const _PublicProfileImageGallery({required this.profile});

  final _SelectionPresentationProfile profile;

  @override
  Widget build(BuildContext context) {
    final images = profile.photoUrls.take(4).toList(growable: false);
    final main = profile.coverUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 0.82,
          child: _PresentationImage(url: main, radius: 24),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: Row(
              children: [
                for (final image in images.skip(1)) ...[
                  Expanded(child: _PresentationImage(url: image, radius: 16)),
                  if (image != images.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PublicSelectionRail extends StatelessWidget {
  const _PublicSelectionRail({
    required this.profiles,
    required this.selectedIndex,
    required this.feedback,
    required this.onSelect,
  });

  final List<_SelectionPresentationProfile> profiles;
  final int selectedIndex;
  final Map<String, SelectionClientFeedback> feedback;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _PresentationPanel(
      padding: const EdgeInsets.all(10),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: profiles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          final vote = feedback[profile.profileId]?.vote;
          final selected = index == selectedIndex;
          final voteIcon = vote == SelectionClientVote.selected
              ? Icons.check_circle_rounded
              : vote == SelectionClientVote.reserve
              ? Icons.bookmark_rounded
              : vote == SelectionClientVote.rejected
              ? Icons.block_rounded
              : Icons.radio_button_unchecked_rounded;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelect(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? BrandTheme.redTop.withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 76,
                      child: _PresentationImage(
                        url: profile.coverUrl,
                        radius: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (profile.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              profile.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kTextMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(voteIcon, color: BrandTheme.redTop, size: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PresentationPanel extends StatelessWidget {
  const _PresentationPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: BrandTheme.lightPillGradient,
        border: Border.all(color: kBorderColor),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _PresentationImage extends StatelessWidget {
  const _PresentationImage({required this.url, required this.radius});

  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.trim().isEmpty
          ? Container(
              color: Colors.black.withValues(alpha: 0.05),
              alignment: Alignment.center,
              child: const Icon(Icons.person_rounded, color: kTextMuted),
            )
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 900,
              maxWidthDiskCache: 1400,
              placeholder: (_, _) =>
                  Container(color: Colors.black.withValues(alpha: 0.04)),
              errorWidget: (_, _, _) => Container(
                color: Colors.black.withValues(alpha: 0.05),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_rounded,
                  color: kTextMuted,
                ),
              ),
            ),
    );
  }
}

class _PresentationStatPill extends StatelessWidget {
  const _PresentationStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: pillDecoration(isDark: false, radius: 999).copyWith(
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: BrandTheme.redTop, size: 18),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: kTextMuted,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresentationInfoChip extends StatelessWidget {
  const _PresentationInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pillDecoration(
        isDark: false,
        radius: 999,
      ).copyWith(border: Border.all(color: kBorderColor)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: BrandTheme.redTop),
          const SizedBox(width: 6),
          Text(
            label,
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
          if (!isPublic && agentFeedback != null && !agentFeedback!.isEmpty)
            _AgentFeedbackView(summary: agentFeedback!)
          else if (!isPublic)
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
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _FeedbackVoteButton(
                  label: isRu ? 'Выбран' : 'Selected',
                  icon: Icons.check_circle_rounded,
                  selected: _vote == SelectionClientVote.selected,
                  onTap: () => _save(vote: SelectionClientVote.selected),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FeedbackVoteButton(
                  label: isRu ? 'Резерв' : 'Reserve',
                  icon: Icons.bookmark_rounded,
                  selected: _vote == SelectionClientVote.reserve,
                  onTap: () => _save(vote: SelectionClientVote.reserve),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FeedbackVoteButton(
                  label: t.clientFeedbackReject,
                  icon: Icons.block_rounded,
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
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

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
                icon: Icons.check_circle_rounded,
                text: isRu
                    ? 'Выбран: ${summary.selected}'
                    : 'Selected: ${summary.selected}',
              ),
              _AgentFeedbackPill(
                icon: Icons.bookmark_rounded,
                text: isRu
                    ? 'Резерв: ${summary.reserve}'
                    : 'Reserve: ${summary.reserve}',
              ),
              _AgentFeedbackPill(
                icon: Icons.block_rounded,
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

class _SelectionStatusPanel extends StatelessWidget {
  const _SelectionStatusPanel({required this.status, required this.onChanged});

  final SelectionStatus status;
  final ValueChanged<SelectionStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return _CardPill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final chips = [
            for (final item in SelectionStatus.values)
              _SelectionStatusChip(
                status: item,
                selected: item == status,
                onTap: () => onChanged(item),
              ),
          ];
          return Column(
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
              if (compact)
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: chips.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => chips[index],
                  ),
                )
              else
                Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          );
        },
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
