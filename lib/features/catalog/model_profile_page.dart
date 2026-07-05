import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/app_error_mapper.dart';
import '../../core/app_logger.dart';
import '../../core/profile_action_log_service.dart';
import '../../core/roles_provider.dart';
import '../../core/public_links.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'agent_workspace.dart';
import 'create_selection_dialog.dart';
import 'model_agent_tools.dart';
import 'model_data.dart';
import 'profile_composite_pdf_service.dart';
import '../admin/selection_providers.dart';
import '../chat/chat_providers.dart';
import '../castings/casting_model.dart';
import '../castings/castings_provider.dart';
import '../analytics/profile_analytics.dart';
import '../profile/profile_model.dart';
import '../profile/profile_supabase_schema.dart';

part 'model_profile_widgets.dart';

const double _pagePadH = 16;
const double _pagePadTop = 18;
const double _pagePadBottom = 24;

const double _sectionGap = 14;
const double _innerGap = 10;

const double _topBarTitleFontSize = 20;
const double _notFoundLetterSpacing = 1.6;
const double _sectionTitleLetterSpacing = 1.55;

const double _iconPillWidth = 58;
const double _iconPillHeight = 52;

const double _heroMediaRadius = 18;
const double _mediaGridGap = 12;
const double _mediaThumbRadius = 16;

const double _galleryCloseOffset = 8;
const double _videoControlsBottom = 24;
const double _videoPlayButtonSize = 56;
const double _videoPreviewLoadingHeight = 180;
const double _videoPreviewHeight = 200;

const Color _titleColor = kTextDark;
const Color _subtitleColor = Color(0xFF4A4A4A);
const Color _topBarTextColor = kTextTitle;
const Color _labelColor = Color(0xFF5A5A5A);

const double _videoThumbIconSize = 28;
const int _profileThumbCacheWidth = 360;
const int _profileHeroCacheWidth = 1200;

TextStyle _commandStyle({
  double fontSize = 16,
  Color color = _titleColor,
  FontWeight weight = FontWeight.w600,
  double? letterSpacing,
}) {
  return BrandTheme.pillText.copyWith(
    fontSize: fontSize,
    letterSpacing: letterSpacing ?? _sectionTitleLetterSpacing,
    fontWeight: weight,
    color: color,
  );
}

TextStyle _bodyStyle({
  double fontSize = 15,
  Color color = _subtitleColor,
  FontWeight weight = FontWeight.w500,
}) {
  return TextStyle(
    fontSize: fontSize,
    height: 1.25,
    letterSpacing: 0,
    color: color,
    fontWeight: weight,
  );
}

final Map<String, Future<String?>> _videoThumbnailFutures =
    <String, Future<String?>>{};

Alignment _profileCoverAlignmentFor(ModelVm m) {
  return Alignment(
    m.coverPhotoFocalX.clamp(-1.0, 1.0),
    m.coverPhotoFocalY.clamp(-1.0, 1.0),
  );
}

String _displayText(String value) => value.trim().isEmpty ? '—' : value.trim();
String _displayInt(int value) => value > 0 ? '$value' : '—';
String _displayNullableInt(int? value) => (value ?? 0) > 0 ? '$value' : '—';
String _displayCm(int value, String cmLabel) =>
    value > 0 ? '$value $cmLabel' : '—';

String _profileTypeLabel(AppLocalizations t, ProfessionalProfileType type) {
  return switch (type) {
    ProfessionalProfileType.model => t.profileTypeModel,
    ProfessionalProfileType.actor => t.profileTypeActor,
    ProfessionalProfileType.photographer => t.profileTypePhotographer,
    ProfessionalProfileType.videographer => t.profileTypeVideographer,
    ProfessionalProfileType.stylist => t.profileTypeStylist,
    ProfessionalProfileType.makeupArtist => t.profileTypeMakeupArtist,
    ProfessionalProfileType.hairStylist => t.profileTypeHairStylist,
  };
}

String _profileRolesLabel(
  AppLocalizations t,
  Iterable<ProfessionalProfileType> roles,
) {
  return normalizeProfileRoles(
    roles,
  ).map((role) => _profileTypeLabel(t, role)).join(' • ');
}

Future<String?> _videoThumbnailForUrl(String rawUrl) {
  final url = rawUrl.trim();
  if (url.isEmpty) return Future<String?>.value(null);

  return _videoThumbnailFutures.putIfAbsent(url, () async {
    try {
      return await VideoThumbnail.thumbnailFile(
        video: url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: kProfileVideoThumbMaxWidth.toInt(),
        quality: kProfileVideoThumbQuality,
      );
    } catch (_) {
      return null;
    }
  });
}

class ModelProfilePage extends ConsumerStatefulWidget {
  const ModelProfilePage({super.key, required this.modelId});
  final String modelId;

  @override
  ConsumerState<ModelProfilePage> createState() => _ModelProfilePageState();
}

enum _ProfileActionKind { invite, selection, folder, message }

class _ProfileActionHistoryItem {
  const _ProfileActionHistoryItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    this.actorName = '',
    this.actorCompany = '',
    this.status = '',
    this.templateKey = '',
    this.templateBody = '',
    this.relatedTable = '',
    this.relatedId = '',
    this.relatedText = '',
    this.deliveredAt,
    this.readAt,
  });

  final _ProfileActionKind kind;
  final String title;
  final String subtitle;
  final DateTime? createdAt;
  final String actorName;
  final String actorCompany;
  final String status;
  final String templateKey;
  final String templateBody;
  final String relatedTable;
  final String relatedId;
  final String relatedText;
  final DateTime? deliveredAt;
  final DateTime? readAt;
}

class _ModelProfilePageState extends ConsumerState<ModelProfilePage> {
  late Future<ModelVm?> _future;
  final GlobalKey _backKey = GlobalKey();
  bool _didInitFuture = false;
  bool _isPortfolioActionBusy = false;

  @override
  void initState() {
    super.initState();
    _future = Future<ModelVm?>.value(null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitFuture) return;
    _didInitFuture = true;
    final fromAdmin =
        GoRouterState.of(context).uri.queryParameters['from'] == 'admin';
    _future = _load(fromAdmin: fromAdmin);
  }

  Future<ModelVm?> _load({required bool fromAdmin}) async {
    final sb = Supabase.instance.client;

    Future<Map<String, dynamic>?> run({
      required bool includeBirthDate,
      required bool includePro,
      required bool includeVerification,
      required bool includeProfessional,
      required bool includeCoverPhoto,
    }) async {
      final row = await sb
          .from(ProfileSupabaseSchema.table)
          .select(
            ProfileSupabaseSchema.selectPublic(
              includeBirthDate: includeBirthDate,
              includeProfessional: includeProfessional,
              includePro: includePro,
              includeVerification: includeVerification,
              includeCoverPhoto: includeCoverPhoto,
            ),
          )
          .eq('id', widget.modelId)
          .maybeSingle();

      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    }

    Map<String, dynamic>? row;
    try {
      row = await run(
        includeBirthDate: true,
        includePro: true,
        includeVerification: true,
        includeProfessional: true,
        includeCoverPhoto: true,
      );
    } on PostgrestException catch (e) {
      final missingPro = ProfileSupabaseSchema.isMissingProColumn(e);
      final missingVerification =
          ProfileSupabaseSchema.isMissingVerificationColumn(e);
      final missingProfessional =
          ProfileSupabaseSchema.isMissingProfessionalColumn(e);
      final missingBirthDate = ProfileSupabaseSchema.isMissingBirthDateColumn(
        e,
      );
      final missingCoverPhoto = ProfileSupabaseSchema.isMissingCoverPhotoColumn(
        e,
      );
      if (!missingPro &&
          !missingVerification &&
          !missingProfessional &&
          !missingBirthDate &&
          !missingCoverPhoto) {
        rethrow;
      }
      row = await run(
        includeBirthDate: !missingBirthDate,
        includePro: !missingPro,
        includeVerification: !missingVerification,
        includeProfessional: !missingProfessional,
        includeCoverPhoto: !missingCoverPhoto,
      );
    }

    if (row == null) return null;

    final status = (row['status'] ?? '').toString();
    if (!fromAdmin && status.isNotEmpty && status != 'approved') {
      return null;
    }

    final model = ModelVm.fromMap(row);
    trackProfileViewLater(ref, model.id);
    return model;
  }

  Future<void> _refresh() async {
    final fromAdmin =
        GoRouterState.of(context).uri.queryParameters['from'] == 'admin';
    setState(() => _future = _load(fromAdmin: fromAdmin));
    await _future;
  }

  Future<void> _copyPublicLink(String profileId) async {
    final t = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: publicProfileLink(profileId)));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.publicLinkCopied)));
  }

  void _back({required bool isAdmin}) {
    final uri = GoRouterState.of(context).uri;
    final from = uri.queryParameters['from'];

    // если есть нормальный stack — просто назад
    if (context.canPop()) {
      context.pop();
      return;
    }

    // кастинг выборка
    if (from == 'casting') {
      final castingId = uri.queryParameters['castingId'];
      if (castingId != null && castingId.isNotEmpty) {
        context.go('${Routes.adminSelection}/$castingId');
        return;
      }
    }

    // проект выборка
    if (from == 'project') {
      final selectionId = uri.queryParameters['selectionId'];
      if (selectionId != null && selectionId.isNotEmpty) {
        context.go('${Routes.adminSelectionProject}/$selectionId');
        return;
      }
    }

    // fallback (старое поведение)
    if (from == 'admin' && isAdmin) {
      context.go(Routes.admin);
    } else {
      context.go(Routes.search);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isAdminAsync = ref.watch(isAdminProvider);
    final isAdmin = isAdminAsync.maybeWhen(data: (v) => v, orElse: () => false);
    final canUseAgentTools = ref
        .watch(canCreateSelectionsProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: FutureBuilder<ModelVm?>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.profileLoadError(
                              AppErrorMapper.message(snap.error, t),
                            ),
                            textAlign: TextAlign.center,
                            style: _bodyStyle(
                              color: BrandTheme.redTop,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _refresh,
                            child: Text(
                              t.retryUpper,
                              style: _commandStyle(
                                fontSize: 14,
                                color: BrandTheme.redTop,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final m = snap.data;
                if (m == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.profileNotFoundUpper,
                            style: _commandStyle(
                              letterSpacing: _notFoundLetterSpacing,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t.profileNotFoundSubtitle,
                            textAlign: TextAlign.center,
                            style: _bodyStyle(),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => _back(isAdmin: isAdmin),
                            child: Text(
                              t.backUpper,
                              style: _commandStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final displayPhotoUrls = m.displayPhotoUrls;

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      _pagePadH,
                      _pagePadTop,
                      _pagePadH,
                      _pagePadBottom,
                    ),
                    children: [
                      _TopBar(
                        backKey: _backKey,
                        title: m.fullName.trim().isEmpty
                            ? t.profileNoName
                            : m.fullName,
                        isPro: m.isProActive,
                        onCopyLink: () => _copyPublicLink(m.id),
                        onBack: () => _back(isAdmin: isAdmin),
                      ),
                      const SizedBox(height: _sectionGap),

                      _Card(
                        child: _PortfolioHeroCard(
                          model: m,
                          t: t,
                          displayPhotoUrls: displayPhotoUrls,
                          coverAlignment: _profileCoverAlignmentFor(m),
                          onOpenPhotos: (index) =>
                              _openPhotos(context, displayPhotoUrls, index),
                          onOpenVideo: m.videoUrls.isEmpty
                              ? null
                              : () => _openVideo(context, m.videoUrls.first),
                          onOpenShowreel: m.hasShowreel
                              ? () => _openVideo(context, m.showreelUrl)
                              : null,
                          onCompositePdf: () => _openCompositePdf(m),
                          onCopyLink: () => _copyPublicLink(m.id),
                          canUseAgentActions: canUseAgentTools,
                          actionHistoryFuture: canUseAgentTools
                              ? _loadProfileActionHistory(m.id)
                              : null,
                          isBusy: _isPortfolioActionBusy,
                          onInvite: () => _inviteFromProfile(m),
                          onAddToSelection: () => _openPortfolioAddSheet(m),
                          onMessage: () => _openProfileChat(m),
                        ),
                      ),
                      const SizedBox(height: _sectionGap),

                      if (m.hasShowreel) ...[
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('SHOWREEL', style: _commandStyle()),
                              const SizedBox(height: 14),
                              _ShowreelCard(
                                videoUrl: m.showreelUrl,
                                previewUrl: m.showreelPreviewUrl,
                                onTap: () => _openVideo(context, m.showreelUrl),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: _sectionGap),
                      ],

                      if (canUseAgentTools) ...[
                        ModelAgentToolsCard(
                          folders: ref.watch(
                            agentFoldersForProfileProvider(m.id),
                          ),
                          note: ref.watch(agentModelNoteProvider(m.id)),
                          onCreateFolder: () => _createAgentFolder(m.id),
                          onToggleFolder: (folder) =>
                              _toggleAgentFolder(m.id, folder),
                          onEditNote: (initial) =>
                              _editAgentNote(profileId: m.id, initial: initial),
                        ),
                        const SizedBox(height: _sectionGap),
                      ],

                      _Card(
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(top: 10),
                            iconColor: _titleColor,
                            collapsedIconColor: _titleColor,
                            title: Text(
                              t.profileDetailsUpper,
                              style: _commandStyle(),
                            ),
                            children: [
                              _DetailsTable(
                                rows: <MapEntry<String, String>>[
                                  MapEntry(
                                    t.profileTypeUpper,
                                    _profileRolesLabel(
                                      t,
                                      m.effectiveProfileRoles,
                                    ),
                                  ),
                                  MapEntry(
                                    t.profileCountry,
                                    _displayText(m.country),
                                  ),
                                  MapEntry(t.profileCity, _displayText(m.city)),
                                  if (m.usesPhysicalBasics) ...[
                                    MapEntry(t.profileAge, _displayInt(m.age)),
                                    MapEntry(
                                      t.profileHeightCm,
                                      _displayCm(m.height, t.cm),
                                    ),
                                  ],
                                  if (m.usesModelMeasurements) ...[
                                    MapEntry(
                                      t.profileBustCm,
                                      _displayCm(m.bust, t.cm),
                                    ),
                                    MapEntry(
                                      t.profileWaistCm,
                                      _displayCm(m.waist, t.cm),
                                    ),
                                    MapEntry(
                                      t.profileHipsCm,
                                      _displayCm(m.hips, t.cm),
                                    ),
                                    MapEntry(
                                      t.profileShoeSize,
                                      _displayNullableInt(m.shoeSize),
                                    ),
                                    MapEntry(
                                      t.profileEyeColor,
                                      _displayText(m.eyeColor),
                                    ),
                                    MapEntry(
                                      t.profileHairColor,
                                      _displayText(m.hairColor),
                                    ),
                                  ],
                                  MapEntry(
                                    t.profileMinHourlyRate,
                                    _displayNullableInt(m.minHourlyRate),
                                  ),
                                  MapEntry(
                                    t.profileMinDailyFee,
                                    _displayNullableInt(m.minDailyFee),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: _sectionGap),

                      if (m.hasProfessionalInfoRole &&
                          [
                            m.experience,
                            m.skills,
                            m.services,
                            m.genres,
                            m.equipment,
                          ].any((value) => value.trim().isNotEmpty)) ...[
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                t.profileProfessionalInfoUpper,
                                style: _commandStyle(),
                              ),
                              const SizedBox(height: _innerGap),
                              _DetailsTable(
                                rows: <MapEntry<String, String>>[
                                  if (m.experience.trim().isNotEmpty)
                                    MapEntry(
                                      t.profileExperience,
                                      _displayText(m.experience),
                                    ),
                                  if (m.skills.trim().isNotEmpty)
                                    MapEntry(
                                      t.profileSkills,
                                      _displayText(m.skills),
                                    ),
                                  if (m.services.trim().isNotEmpty)
                                    MapEntry(
                                      t.profileServices,
                                      _displayText(m.services),
                                    ),
                                  if (m.genres.trim().isNotEmpty)
                                    MapEntry(
                                      t.profileWorkGenres,
                                      _displayText(m.genres),
                                    ),
                                  if (m.equipment.trim().isNotEmpty)
                                    MapEntry(
                                      t.profileEquipment,
                                      _displayText(m.equipment),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: _sectionGap),
                      ],

                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(t.profileMediaUpper, style: _commandStyle()),
                            const SizedBox(height: 14),
                            if (displayPhotoUrls.isEmpty && m.videoUrls.isEmpty)
                              Text(t.profileMediaEmpty, style: _bodyStyle())
                            else
                              _MediaGrid(
                                photoUrls: displayPhotoUrls,
                                photoCategoryLabels: m.photoCategoryLabels,
                                videoUrls: m.videoUrls,
                                videoPreviewUrls: m.videoPreviewUrls,
                                videoCategoryLabels: m.videoCategoryLabels,
                                showreelUrl: m.showreelUrl,
                                onOpenPhotos: (index) => _openPhotos(
                                  context,
                                  displayPhotoUrls,
                                  index,
                                ),
                                onOpenVideo: (index) =>
                                    _openVideo(context, m.videoUrls[index]),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: _sectionGap),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(t.profileResumeUpper, style: _commandStyle()),
                            const SizedBox(height: _innerGap),
                            Text(
                              m.resume.trim().isEmpty
                                  ? t.profileResumeEmpty
                                  : m.resume,
                              style: _bodyStyle(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runPortfolioAction(Future<void> Function() action) async {
    if (_isPortfolioActionBusy) return;
    setState(() => _isPortfolioActionBusy = true);
    try {
      await action();
    } catch (e) {
      assert(() {
        AppLogger.error('Profile portfolio action failed', error: e);
        return true;
      }());
      if (!mounted) return;
      _showSnack(AppErrorMapper.message(e, AppLocalizations.of(context)!));
    } finally {
      if (mounted) setState(() => _isPortfolioActionBusy = false);
    }
  }

  Future<List<_ProfileActionHistoryItem>> _loadProfileActionHistory(
    String profileId,
  ) async {
    final id = profileId.trim();
    if (id.isEmpty) return const <_ProfileActionHistoryItem>[];
    final items = <_ProfileActionHistoryItem>[];
    final sb = Supabase.instance.client;

    final auditRows = await ProfileActionLogService(
      sb,
    ).fetchForProfile(profileId: id, limit: 8);
    if (auditRows != null && auditRows.isNotEmpty) {
      return auditRows.map(_profileActionFromAuditRow).take(8).toList();
    }

    await _appendInvitationActions(sb, id, items);
    await _appendSelectionActions(sb, id, items);
    await _appendFolderActions(sb, id, items);
    await _appendMessageActions(sb, id, items);

    items.sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return items.take(6).toList(growable: false);
  }

  _ProfileActionHistoryItem _profileActionFromAuditRow(
    ProfileActionLogEntry row,
  ) {
    final kind = switch (row.actionType) {
      'selection' => _ProfileActionKind.selection,
      'folder' => _ProfileActionKind.folder,
      'message' => _ProfileActionKind.message,
      _ => _ProfileActionKind.invite,
    };
    return _ProfileActionHistoryItem(
      kind: kind,
      title: row.title,
      subtitle: row.description,
      actorName: row.actorName,
      actorCompany: row.actorCompany,
      status: row.status,
      templateKey: row.templateKey,
      templateBody: row.templateBody,
      relatedTable: row.relatedTable,
      relatedId: row.relatedId,
      relatedText: row.relatedText,
      deliveredAt: row.deliveredAt,
      readAt: row.readAt,
      createdAt: row.createdAt,
    );
  }

  Future<void> _appendInvitationActions(
    SupabaseClient sb,
    String profileId,
    List<_ProfileActionHistoryItem> items,
  ) async {
    try {
      final rows = await sb
          .from('casting_responses')
          .select('created_at,status,casting:castings(title)')
          .eq('profile_id', profileId)
          .eq('status', 'invited')
          .order('created_at', ascending: false)
          .limit(4);
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final casting = row['casting'] is Map
            ? Map<String, dynamic>.from(row['casting'] as Map)
            : const <String, dynamic>{};
        final title = (casting['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        items.add(
          _ProfileActionHistoryItem(
            kind: _ProfileActionKind.invite,
            title: title,
            subtitle: 'self',
            createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _appendSelectionActions(
    SupabaseClient sb,
    String profileId,
    List<_ProfileActionHistoryItem> items,
  ) async {
    try {
      final rows = await sb
          .from('selection_items')
          .select('created_at,selection:selections(title)')
          .eq('profile_id', profileId)
          .order('created_at', ascending: false)
          .limit(4);
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final selection = row['selection'] is Map
            ? Map<String, dynamic>.from(row['selection'] as Map)
            : const <String, dynamic>{};
        final title = (selection['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        items.add(
          _ProfileActionHistoryItem(
            kind: _ProfileActionKind.selection,
            title: title,
            subtitle: 'self',
            createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _appendFolderActions(
    SupabaseClient sb,
    String profileId,
    List<_ProfileActionHistoryItem> items,
  ) async {
    try {
      final rows = await sb
          .from('casting_agent_folder_items')
          .select('created_at,folder:casting_agent_folders(title)')
          .eq('profile_id', profileId)
          .order('created_at', ascending: false)
          .limit(4);
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final folder = row['folder'] is Map
            ? Map<String, dynamic>.from(row['folder'] as Map)
            : const <String, dynamic>{};
        final title = (folder['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        items.add(
          _ProfileActionHistoryItem(
            kind: _ProfileActionKind.folder,
            title: title,
            subtitle: 'self',
            createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _appendMessageActions(
    SupabaseClient sb,
    String profileId,
    List<_ProfileActionHistoryItem> items,
  ) async {
    try {
      final chats = await sb
          .from('selection_chats')
          .select('id')
          .eq('profile_id', profileId)
          .limit(20);
      final chatIds = (chats as List)
          .map((row) => ((row as Map)['id'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (chatIds.isEmpty) return;
      final rows = await sb
          .from('selection_chat_messages')
          .select('created_at,body,media_type,sender_id')
          .filter('chat_id', 'in', '(${chatIds.join(',')})')
          .order('created_at', ascending: false)
          .limit(4);
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final body = (row['body'] ?? '').toString().trim();
        final mediaType = (row['media_type'] ?? '').toString().trim();
        final title = body.isNotEmpty
            ? body
            : mediaType.isNotEmpty
            ? mediaType
            : 'message';
        final senderId = (row['sender_id'] ?? '').toString().trim();
        final currentUserId = sb.auth.currentUser?.id ?? '';
        items.add(
          _ProfileActionHistoryItem(
            kind: _ProfileActionKind.message,
            title: title,
            subtitle: senderId.isNotEmpty && senderId == currentUserId
                ? 'outgoing'
                : 'incoming',
            createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _openPortfolioAddSheet(ModelVm model) async {
    final folders = await ref.read(agentFoldersProvider.future);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (_) => _PortfolioAddSheet(
        modelName: model.fullName,
        folders: folders,
        onFavorite: () {
          Navigator.of(context).pop();
          _addProfileToFavorite(model);
        },
        onCreateSelection: () {
          Navigator.of(context).pop();
          _createProfileSelection(model);
        },
        onCreateFolder: () {
          Navigator.of(context).pop();
          _createFolderAndAddProfile(model);
        },
        onAddToFolder: (folder) {
          Navigator.of(context).pop();
          _addProfileToFolder(model, folder);
        },
      ),
    );
  }

  Future<void> _addProfileToFavorite(ModelVm model) async {
    final profileId = model.id;
    final t = AppLocalizations.of(context)!;
    await _runPortfolioAction(() async {
      await ref
          .read(agentWorkspaceServiceProvider)
          .addProfileToNamedFolder(
            title: t.agentFavoriteFolderTitle,
            profileId: profileId,
          );
      ref.invalidate(agentFoldersForProfileProvider(profileId));
      await _logProfileAction(
        model: model,
        actionType: 'folder',
        title: t.agentFavoriteFolderTitle,
        description: 'favorite',
        relatedTable: 'casting_agent_folders',
        relatedText: t.agentFavoriteFolderTitle,
      );
      ref.invalidate(agentFoldersProvider);
      if (mounted) setState(() {});
      _showSnack(t.quickAddFavoriteDone);
    });
  }

  Future<void> _addProfileToFolder(ModelVm model, AgentFolder folder) async {
    final profileId = model.id;
    final t = AppLocalizations.of(context)!;
    await _runPortfolioAction(() async {
      await ref
          .read(agentWorkspaceServiceProvider)
          .setProfileInFolder(
            folderId: folder.id,
            profileId: profileId,
            selected: true,
          );
      ref.invalidate(agentFoldersForProfileProvider(profileId));
      await _logProfileAction(
        model: model,
        actionType: 'folder',
        title: folder.title,
        description: 'folder',
        relatedTable: 'casting_agent_folders',
        relatedId: folder.id,
        relatedText: folder.title,
      );
      ref.invalidate(agentFoldersProvider);
      if (mounted) setState(() {});
      _showSnack(t.quickAddFolderDone(folder.title));
    });
  }

  Future<void> _createFolderAndAddProfile(ModelVm model) async {
    final profileId = model.id;
    final t = AppLocalizations.of(context)!;
    final title = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AgentTextInputDialog(
        title: t.agentFolderCreateTitle,
        hint: t.agentFolderName,
        actionLabel: t.saveUpper,
      ),
    );
    if (!mounted || title == null || title.trim().isEmpty) return;

    await _runPortfolioAction(() async {
      await ref
          .read(agentWorkspaceServiceProvider)
          .addProfileToNamedFolder(title: title, profileId: profileId);
      ref.invalidate(agentFoldersForProfileProvider(profileId));
      await _logProfileAction(
        model: model,
        actionType: 'folder',
        title: title.trim(),
        description: 'folder',
        relatedTable: 'casting_agent_folders',
        relatedText: title.trim(),
      );
      ref.invalidate(agentFoldersProvider);
      if (mounted) setState(() {});
      _showSnack(t.quickAddFolderDone(title.trim()));
    });
  }

  Future<void> _createProfileSelection(ModelVm model) async {
    final draft = await showDialog<SelectionDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CreateSelectionDialog(),
    );
    if (!mounted || draft == null || draft.title.trim().isEmpty) return;

    final t = AppLocalizations.of(context)!;
    await _runPortfolioAction(() async {
      await _createSelectionWithItems(draft: draft, profileIds: [model.id]);
      await _logProfileAction(
        model: model,
        actionType: 'selection',
        title: draft.title.trim(),
        description: 'selection',
        relatedTable: 'selections',
        relatedText: draft.title.trim(),
      );
      ref.invalidate(adminSelectionListProvider);
      if (mounted) setState(() {});
      _showSnack(t.quickAddSelectionDone(draft.title.trim()));
    });
  }

  Future<void> _openProfileChat(ModelVm model) async {
    await _runPortfolioAction(() async {
      final chatId = await _ensurePortfolioChat(model);
      if (!mounted || chatId.isEmpty) return;
      ref.invalidate(myChatsProvider(false));
      context.push('${Routes.chatPrefix}$chatId');
    });
  }

  Future<void> _inviteFromProfile(ModelVm model) async {
    final t = AppLocalizations.of(context)!;
    List<CastingModel> castings;
    try {
      castings = await ref.read(castingsProvider.future);
    } catch (e) {
      if (!mounted) return;
      _showSnack(AppErrorMapper.message(e, t));
      return;
    }
    if (!mounted) return;

    final draft = await showModalBottomSheet<_ProfileInviteDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => _ProfileInviteSheet(
        modelName: model.fullName.trim().isEmpty
            ? t.profileNoName
            : model.fullName.trim(),
        castings: castings,
      ),
    );
    if (!mounted || draft == null) return;

    await _runPortfolioAction(() async {
      final chatId = await _ensurePortfolioChat(model);
      if (chatId.isEmpty) return;
      if (draft.casting != null) {
        await _markProfileInvitedToCasting(
          model: model,
          casting: draft.casting!,
        );
      }
      await ref
          .read(chatServiceProvider)
          .sendMessage(chatId: chatId, body: draft.message);
      await _logProfileAction(
        model: model,
        actionType: 'invite',
        title: draft.casting?.title.trim().isNotEmpty == true
            ? draft.casting!.title.trim()
            : (t.localeName.toLowerCase().startsWith('ru')
                  ? 'Приглашение'
                  : 'Invitation'),
        description: draft.casting == null ? 'invite_chat' : 'invite_casting',
        templateKey: draft.templateKey,
        templateBody: draft.templateBody,
        status: 'sent',
        relatedTable: draft.casting == null ? 'selection_chats' : 'castings',
        relatedId: draft.casting?.id ?? chatId,
        relatedText: draft.casting?.title ?? '',
      );
      await ref.read(profileAnalyticsServiceProvider).trackInvitation(model.id);
      ref.invalidate(myChatsProvider(false));
      ref.invalidate(myCastingResponseStatusesProvider);
      if (mounted) setState(() {});
      if (!mounted) return;
      _showSnack(
        t.localeName.toLowerCase().startsWith('ru')
            ? 'Приглашение отправлено'
            : 'Invitation sent',
      );
      context.push('${Routes.chatPrefix}$chatId');
    });
  }

  Future<void> _logProfileAction({
    required ModelVm model,
    required String actionType,
    required String title,
    String description = '',
    String templateKey = '',
    String templateBody = '',
    String status = 'created',
    String relatedTable = '',
    String relatedId = '',
    String relatedText = '',
  }) async {
    await ProfileActionLogService(Supabase.instance.client).log(
      profileId: model.id,
      targetUserId: model.userId,
      actionType: actionType,
      title: title,
      description: description,
      templateKey: templateKey,
      templateBody: templateBody,
      status: status,
      relatedTable: relatedTable,
      relatedId: relatedId,
      relatedText: relatedText,
    );
  }

  Future<void> _markProfileInvitedToCasting({
    required ModelVm model,
    required CastingModel casting,
  }) async {
    final castingId = casting.id.trim();
    if (castingId.isEmpty) return;
    try {
      await Supabase.instance.client.from('casting_responses').upsert({
        'casting_id': castingId,
        'profile_id': model.id,
        'user_id': model.userId,
        'status': 'invited',
      }, onConflict: 'casting_id,profile_id');
    } on PostgrestException catch (e) {
      final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
          .toLowerCase();
      if (!msg.contains('status') && !msg.contains('schema cache')) rethrow;
      await Supabase.instance.client.from('casting_responses').upsert({
        'casting_id': castingId,
        'profile_id': model.id,
        'user_id': model.userId,
      }, onConflict: 'casting_id,profile_id');
    }
  }

  Future<String> _ensurePortfolioChat(ModelVm model) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (currentUserId.isEmpty || model.userId.trim().isEmpty) return '';
    if (currentUserId == model.userId.trim()) {
      _showSnack(
        AppLocalizations.of(context)!.localeName.toLowerCase().startsWith('ru')
            ? 'Это ваша анкета'
            : 'This is your own profile',
      );
      return '';
    }

    final selectionId = await _ensureQuickContactSelection(model);
    if (selectionId.isEmpty) return '';
    return ref
        .read(chatServiceProvider)
        .ensureSelectionChat(
          selectionId: selectionId,
          profileId: model.id,
          modelUserId: model.userId,
        );
  }

  Future<String> _ensureQuickContactSelection(ModelVm model) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return '';

    final title =
        AppLocalizations.of(context)!.localeName.toLowerCase().startsWith('ru')
        ? 'Быстрые контакты'
        : 'Quick contacts';

    String selectionId = '';
    try {
      final existing = await sb
          .from('selections')
          .select('id')
          .eq('created_by', uid)
          .eq('title', title)
          .order('created_at', ascending: false)
          .limit(1);
      if (existing.isNotEmpty) {
        selectionId = ((existing.first as Map)['id'] ?? '').toString();
      }
    } on PostgrestException {
      // Fallback below can still create a selection on older schemas.
    }

    if (selectionId.isEmpty) {
      final inserted = await sb
          .from('selections')
          .insert({'title': title, 'created_by': uid})
          .select('id')
          .single();
      selectionId = (inserted['id'] ?? '').toString();
    }
    if (selectionId.isEmpty) return '';

    try {
      await sb.from('selection_items').insert({
        'selection_id': selectionId,
        'profile_id': model.id,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        final message = '${e.message} ${e.details ?? ''}'.toLowerCase();
        if (!message.contains('duplicate')) rethrow;
      }
    }
    return selectionId;
  }

  Future<void> _createSelectionWithItems({
    required SelectionDraft draft,
    required List<String> profileIds,
  }) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;

    Future<bool> createViaRpc() async {
      try {
        await sb.rpc(
          'create_selection_with_items',
          params: {
            'p_title': draft.title,
            'p_profile_ids': profileIds,
            'p_request_video_intro': draft.requestVideoIntro,
            'p_video_intro_requirements': draft.videoIntroRequirements,
          },
        );
        return true;
      } on PostgrestException catch (e) {
        final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
            .toLowerCase();
        if (msg.contains('create_selection_with_items') ||
            msg.contains('function') ||
            msg.contains('schema cache') ||
            e.code == 'PGRST202') {
          return false;
        }
        rethrow;
      }
    }

    if (await createViaRpc()) return;

    Future<Map<String, dynamic>> insertSelection({
      required bool includeVideoRequest,
      required bool includeCampaignFields,
    }) async {
      final payload = <String, dynamic>{
        'title': draft.title,
        if (uid != null) 'created_by': uid,
        if (includeCampaignFields) 'client_name': draft.clientName,
        if (includeCampaignFields) 'brand_name': draft.brandName,
        if (includeCampaignFields) 'budget': draft.budget,
        if (includeCampaignFields) 'location': draft.location,
        if (includeCampaignFields) 'project_dates': draft.projectDates,
        if (includeCampaignFields) 'project_roles': draft.projectRoles,
        if (includeVideoRequest) 'request_video_intro': draft.requestVideoIntro,
        if (includeVideoRequest)
          'video_intro_requirements': draft.videoIntroRequirements,
      };
      return await sb.from('selections').insert(payload).select('id').single();
    }

    Map<String, dynamic> inserted;
    try {
      inserted = await insertSelection(
        includeVideoRequest: true,
        includeCampaignFields: true,
      );
    } on PostgrestException catch (e) {
      final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
          .toLowerCase();
      if (!msg.contains('client_name') &&
          !msg.contains('brand_name') &&
          !msg.contains('budget') &&
          !msg.contains('location') &&
          !msg.contains('project_dates') &&
          !msg.contains('project_roles') &&
          !msg.contains('request_video_intro') &&
          !msg.contains('video_intro_requirements') &&
          !msg.contains('schema cache')) {
        rethrow;
      }
      try {
        inserted = await insertSelection(
          includeVideoRequest: true,
          includeCampaignFields: false,
        );
      } on PostgrestException {
        inserted = await insertSelection(
          includeVideoRequest: false,
          includeCampaignFields: false,
        );
      }
    }

    final selectionId = (inserted['id'] ?? '').toString();
    if (selectionId.isEmpty) throw StateError('selection_insert_failed');

    await sb.from('selection_items').insert([
      for (final profileId in profileIds)
        {'selection_id': selectionId, 'profile_id': profileId},
    ]);
    ref.invalidate(adminSelectionListProvider);
  }

  void _openPhotos(BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _PhotoGalleryPage(urls: urls, initialIndex: initialIndex),
      ),
    );
  }

  Future<void> _openCompositePdf(ModelVm model) async {
    final t = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    try {
      await const ProfileCompositePdfService().previewComposite(
        t: t,
        model: model,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(AppErrorMapper.message(e, t))));
    }
  }

  void _openVideo(BuildContext context, String url) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _FullScreenVideoPage(url: url)));
  }

  Future<void> _createAgentFolder(String profileId) async {
    final t = AppLocalizations.of(context)!;
    final title = await showDialog<String>(
      context: context,
      builder: (_) => AgentTextInputDialog(
        title: t.agentFolderCreateTitle,
        hint: t.agentFolderName,
        actionLabel: t.agentFolderCreateUpper,
      ),
    );
    if (!mounted || title == null || title.trim().isEmpty) return;

    await ref.read(agentWorkspaceServiceProvider).createFolder(title);
    ref.invalidate(agentFoldersForProfileProvider(profileId));
  }

  Future<void> _toggleAgentFolder(String profileId, AgentFolder folder) async {
    await ref
        .read(agentWorkspaceServiceProvider)
        .setProfileInFolder(
          folderId: folder.id,
          profileId: profileId,
          selected: !folder.containsProfile,
        );
    ref.invalidate(agentFoldersForProfileProvider(profileId));
  }

  Future<void> _editAgentNote({
    required String profileId,
    required String initial,
  }) async {
    final t = AppLocalizations.of(context)!;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AgentTextInputDialog(
        title: t.agentPrivateNoteUpper,
        hint: t.agentNoteHint,
        initial: initial,
        actionLabel: t.save,
        maxLines: 5,
      ),
    );
    if (!mounted || note == null) return;

    await ref
        .read(agentWorkspaceServiceProvider)
        .saveNote(profileId: profileId, note: note);
    ref.invalidate(agentModelNoteProvider(profileId));
  }
}
