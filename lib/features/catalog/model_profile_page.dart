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
import '../../core/roles_provider.dart';
import '../../core/public_links.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'agent_workspace.dart';
import 'model_agent_tools.dart';
import 'model_data.dart';
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

class _ModelProfilePageState extends ConsumerState<ModelProfilePage> {
  late Future<ModelVm?> _future;
  final GlobalKey _backKey = GlobalKey();
  bool _didInitFuture = false;

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
    }) async {
      final row = await sb
          .from(ProfileSupabaseSchema.table)
          .select(
            ProfileSupabaseSchema.selectPublic(
              includeBirthDate: includeBirthDate,
              includeProfessional: includeProfessional,
              includePro: includePro,
              includeVerification: includeVerification,
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
      if (!missingPro &&
          !missingVerification &&
          !missingProfessional &&
          !missingBirthDate) {
        rethrow;
      }
      row = await run(
        includeBirthDate: !missingBirthDate,
        includePro: !missingPro,
        includeVerification: !missingVerification,
        includeProfessional: !missingProfessional,
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

                      (m.photoUrls.isNotEmpty || m.videoUrls.isNotEmpty)
                          ? _Card(
                              child: _HeroMedia(
                                photoUrls: m.photoUrls,
                                videoUrls: m.videoUrls,
                                videoPreviewUrls: m.videoPreviewUrls,
                                heroTag: 'model-photo-${m.id}',
                                onOpenPhotos: (index) =>
                                    _openPhotos(context, m.photoUrls, index),
                                onOpenVideo: () =>
                                    _openVideo(context, m.videoUrls.first),
                              ),
                            )
                          : const SizedBox.shrink(),
                      (m.photoUrls.isNotEmpty || m.videoUrls.isNotEmpty)
                          ? const SizedBox(height: 14)
                          : const SizedBox.shrink(),

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
                                    _profileTypeLabel(t, m.profileType),
                                  ),
                                  MapEntry(
                                    t.profileCountry,
                                    _displayText(m.country),
                                  ),
                                  MapEntry(t.profileCity, _displayText(m.city)),
                                  if (m.profileType.usesPhysicalBasics) ...[
                                    MapEntry(t.profileAge, _displayInt(m.age)),
                                    MapEntry(
                                      t.profileHeightCm,
                                      _displayCm(m.height, t.cm),
                                    ),
                                  ],
                                  if (m.profileType.usesModelMeasurements) ...[
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

                      if (!m.profileType.isModel &&
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
                            if (m.photoUrls.isEmpty && m.videoUrls.isEmpty)
                              Text(t.profileMediaEmpty, style: _bodyStyle())
                            else
                              _MediaGrid(
                                photoUrls: m.photoUrls,
                                videoUrls: m.videoUrls,
                                videoPreviewUrls: m.videoPreviewUrls,
                                onOpenPhotos: (index) =>
                                    _openPhotos(context, m.photoUrls, index),
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

  void _openPhotos(BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _PhotoGalleryPage(urls: urls, initialIndex: initialIndex),
      ),
    );
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
