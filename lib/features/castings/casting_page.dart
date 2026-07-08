import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error_mapper.dart';
import '../../core/admin_action_log_service.dart';
import '../../core/app_logger.dart';
import '../../core/open_external_url_stub.dart'
    if (dart.library.html) '../../core/open_external_url_web.dart';
import '../../core/router.dart';
import '../../core/roles_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../profile/my_profile_controller.dart';
import '../profile/profile_model.dart';
import '../../ui/brand/brand_logo.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/ui_constants.dart';
import '../../core/auth_providers.dart';
import 'casting_project_stage.dart';
import 'casting_reference_media.dart';
import 'casting_response_status.dart';
import 'casting_model.dart';
import 'castings_service.dart';
import 'castings_provider.dart';
import 'casting_card.dart';

const double _castingsDesktopBreakpoint = 900;
const double _castingsDesktopMaxWidth = 1480;
const double _castingsDesktopListWidth = 440;
const double _castingsDesktopDetailBreakpoint = 1040;
const EdgeInsets _castingsDesktopPadding = EdgeInsets.fromLTRB(32, 24, 32, 28);

String _castingLocaleText(BuildContext context, String ru, String en) {
  return Localizations.localeOf(context).languageCode == 'ru' ? ru : en;
}

String _castingAdminErrorText(Object error, AppLocalizations t) {
  final source = error is CastingsException ? error.original : error;
  if (source is PostgrestException) {
    final parts = <String>[source.message.trim()];
    final details = (source.details ?? '').toString().trim();
    final hint = (source.hint ?? '').trim();
    final code = (source.code ?? '').trim();
    if (details.isNotEmpty) parts.add(details);
    if (hint.isNotEmpty) parts.add(hint);
    if (code.isNotEmpty) parts.add('code: $code');
    parts.removeWhere((part) => part.isEmpty);
    if (parts.isNotEmpty) return parts.join('\n');
  }
  return AppErrorMapper.message(error, t, original: source);
}

void _showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1F1F1F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Text(
          text,
          style: BrandTheme.pillText.copyWith(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
}

Future<bool> _showDeleteCastingConfirm(
  BuildContext context,
  AppLocalizations t,
) async {
  final isRu = Localizations.localeOf(context).languageCode == 'ru';
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kCastingDialogInsetPad,
      child: Container(
        decoration: castingDialogDecoration(),
        padding: kCastingDialogPad,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isRu ? 'УДАЛИТЬ КАСТИНГ?' : 'DELETE CASTING?',
              textAlign: TextAlign.center,
              style: kCastingDialogTitleStyle,
            ),
            const SizedBox(height: kGap10),
            Text(
              isRu
                  ? 'Кастинг, отклики и связанные чаты будут удалены.'
                  : 'The casting, responses, and related chats will be deleted.',
              textAlign: TextAlign.center,
              style: kCastingDialogBodyStyle,
            ),
            const SizedBox(height: kGap16),
            Row(
              children: [
                Expanded(
                  child: BrandPillButton(
                    label: t.cancelUpper,
                    style: BrandPillStyle.light,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrandPillButton(
                    label: t.deleteUpper,
                    style: BrandPillStyle.dark,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return result ?? false;
}

Future<void> _showAuthRequiredDialog(
  BuildContext context,
  AppLocalizations t,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kCastingDialogInsetPad,
      child: Container(
        decoration: castingDialogDecoration(),
        padding: kCastingDialogPad,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.respondAuthRequiredTitle,
              textAlign: TextAlign.center,
              style: kCastingDialogTitleStyle,
            ),
            const SizedBox(height: kGap10),
            Text(
              t.respondAuthRequiredMessage,
              textAlign: TextAlign.center,
              style: kCastingDialogBodyStyle,
            ),
            const SizedBox(height: kGap16),
            Row(
              children: [
                Expanded(
                  child: BrandPillButton(
                    label: t.cancelUpper,
                    style: BrandPillStyle.light,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kGap10),
            Row(
              children: [
                Expanded(
                  child: BrandPillButton(
                    label: t.registerUpper,
                    style: BrandPillStyle.light,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      context.go(Routes.register);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrandPillButton(
                    label: t.signInUpper,
                    style: BrandPillStyle.dark,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      context.go(Routes.login);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showRespondSentSnack(
  BuildContext context,
  AppLocalizations t,
) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF1F1F1F),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Text(
        t.respondSentMessage,
        style: BrandTheme.pillText.copyWith(
          color: Colors.white,
          fontSize: 14,
          letterSpacing: 0.4,
        ),
      ),
    ),
  );
}

Future<void> _chooseProfilesAndRespond({
  required BuildContext context,
  required AppLocalizations t,
  required List<MyProfileState> profiles,
  required CastingsService service,
  required String userId,
  required String castingId,
  required Set<String> alreadyRespondedProfileIds,
}) async {
  final availableProfiles = profiles
      .where((p) => !alreadyRespondedProfileIds.contains(p.id.trim()))
      .toList(growable: false);

  if (profiles.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: kCastingDialogInsetPad,
        child: Container(
          decoration: castingDialogDecoration(),
          padding: kCastingDialogPad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.respondNoProfilesTitle,
                textAlign: TextAlign.center,
                style: kCastingDialogTitleStyle,
              ),
              const SizedBox(height: kGap10),
              Text(
                t.respondNoProfilesMessage,
                textAlign: TextAlign.center,
                style: kCastingDialogBodyStyle,
              ),
              const SizedBox(height: kGap16),
              Row(
                children: [
                  Expanded(
                    child: BrandPillButton(
                      label: t.cancelUpper,
                      style: BrandPillStyle.light,
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrandPillButton(
                      label: t.goToProfileUpper,
                      style: BrandPillStyle.dark,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        context.go(Routes.me);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

  if (availableProfiles.isEmpty) {
    _showSnack(
      context,
      _castingLocaleText(
        context,
        'Все ваши анкеты уже добавлены в этот кастинг',
        'All your profiles are already added to this casting',
      ),
    );
    return;
  }

  if (availableProfiles.length == 1) {
    final p = availableProfiles.first;
    final pid = p.id.trim();
    if (pid.isNotEmpty) {
      await service.respond(
        castingId: castingId,
        profileId: pid,
        userId: userId,
      );
    }
    if (!context.mounted) return;
    await _showRespondSentSnack(context, t);
    return;
  }

  final selectedIds = <String>{};
  var didConfirm = false;
  var selectedToSend = <String>[];
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kCastingDialogInsetPad,
      child: StatefulBuilder(
        builder: (ctx, setState) {
          return Container(
            decoration: castingDialogDecoration(),
            padding: kCastingDialogPad,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: kCastingDialogMaxH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.respondChooseProfilesTitle,
                    textAlign: TextAlign.center,
                    style: kCastingDialogTitleStyle,
                  ),
                  const SizedBox(height: kGap10),
                  Text(
                    t.respondChooseProfilesMessage,
                    textAlign: TextAlign.center,
                    style: kCastingDialogBodyStyle,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: availableProfiles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final p = availableProfiles[i];
                        final id = p.id.trim();
                        final title = p.fullName.trim().isNotEmpty
                            ? p.fullName.trim()
                            : '${t.profileUpper} ${i + 1}';
                        final checked = selectedIds.contains(id);

                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              kCastingProfileTileRadius,
                            ),
                            color: Colors.white.withValues(alpha: 0.35),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: checked,
                            activeColor: BrandTheme.redTop,
                            checkColor: Colors.white,
                            fillColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return BrandTheme.redTop;
                              }
                              return Colors.transparent;
                            }),
                            side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.25),
                              width: 1,
                            ),
                            onChanged: (v) {
                              setState(() {
                                if ((v ?? false) && id.isNotEmpty) {
                                  selectedIds.add(id);
                                } else {
                                  selectedIds.remove(id);
                                }
                              });
                            },
                            title: Text(
                              title,
                              style: kCastingBodyStyle.copyWith(
                                color: kTextDark,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: kCastingProfileTileContentPad,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: BrandPillButton(
                          label: t.cancelUpper,
                          style: BrandPillStyle.light,
                          onTap: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BrandPillButton(
                          label: t.respondUpper,
                          style: BrandPillStyle.dark,
                          onTap: selectedIds.isEmpty
                              ? null
                              : () {
                                  didConfirm = true;
                                  selectedToSend = selectedIds.toList(
                                    growable: false,
                                  );
                                  Navigator.of(ctx).pop();
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  if (didConfirm) {
    if (selectedToSend.isNotEmpty) {
      await service.respondMany(
        castingId: castingId,
        profileIds: selectedToSend,
        userId: userId,
      );
    }
    if (!context.mounted) return;
    await _showRespondSentSnack(context, t);
  }
}

Future<void> _onRespondTap({
  required WidgetRef ref,
  required BuildContext context,
  required AppLocalizations t,
  required AsyncValue<List<MyProfileState>> myProfiles,
  required String castingId,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    await _showAuthRequiredDialog(context, t);
    return;
  }

  final profiles = myProfiles.when(
    data: (v) => v,
    loading: () => null,
    error: (_, _) => null,
  );
  if (profiles == null) {
    _showSnack(context, t.signInGenericError);
    return;
  }

  final respondingNow = ref.read(respondingCastingsProvider);
  if (respondingNow.contains(castingId)) return;

  ref.read(respondingCastingsProvider.notifier).state = <String>{
    ...respondingNow,
    castingId,
  };

  try {
    final service = ref.read(castingsServiceProvider);
    final alreadyRespondedProfileIds = await service.fetchMyRespondedProfileIds(
      castingId: castingId,
      userId: userId,
    );
    if (!context.mounted) return;
    await _chooseProfilesAndRespond(
      context: context,
      t: t,
      profiles: profiles,
      service: service,
      userId: userId,
      castingId: castingId,
      alreadyRespondedProfileIds: alreadyRespondedProfileIds,
    );
  } on CastingsException catch (e) {
    AppLogger.error('Casting response failed', error: e.original ?? e);
    if (!context.mounted) return;
    _showSnack(context, t.signInGenericError);
  } catch (e, stack) {
    AppLogger.error('Casting response failed', error: e, stackTrace: stack);
    if (!context.mounted) return;
    _showSnack(context, t.signInGenericError);
  } finally {
    final cur = ref.read(respondingCastingsProvider);
    final next = <String>{...cur}..remove(castingId);
    ref.read(respondingCastingsProvider.notifier).state = next;
    ref.invalidate(myCastingResponseStatusesProvider);
  }
}

Future<void> _onDeleteCastingTap({
  required WidgetRef ref,
  required BuildContext context,
  required AppLocalizations t,
  required String castingId,
}) async {
  final confirmed = await _showDeleteCastingConfirm(context, t);
  if (!context.mounted || !confirmed) return;

  try {
    await ref.read(castingsServiceProvider).deleteCasting(castingId);
    await AdminActionLogService(Supabase.instance.client).log(
      actionType: 'casting_deleted',
      title: 'Кастинг удален',
      targetTable: 'castings',
      targetId: castingId,
      targetText: castingId,
      status: 'deleted',
    );
    ref.invalidate(castingsProvider);
    ref.invalidate(myCastingResponseStatusesProvider);
    if (!context.mounted) return;
    _showSnack(
      context,
      Localizations.localeOf(context).languageCode == 'ru'
          ? 'Кастинг удален'
          : 'Casting deleted',
    );
  } on CastingsException catch (e, st) {
    AppLogger.error(
      'Casting delete failed',
      error: e.original ?? e,
      stackTrace: st,
    );
    if (!context.mounted) return;
    _showSnack(context, _castingAdminErrorText(e, t));
  } catch (e, st) {
    AppLogger.error('Casting delete failed', error: e, stackTrace: st);
    if (!context.mounted) return;
    _showSnack(context, _castingAdminErrorText(e, t));
  }
}

Future<CastingProjectStage?> _showCastingStagePicker({
  required BuildContext context,
  required CastingProjectStage current,
}) async {
  final isRu = Localizations.localeOf(context).languageCode == 'ru';
  return showModalBottomSheet<CastingProjectStage>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          decoration: castingDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isRu ? 'ЭТАП ПРОЕКТА' : 'PROJECT STAGE',
                      style: kCastingDialogTitleStyle,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final stage in CastingProjectStage.values) ...[
                _CastingStagePickerTile(
                  stage: stage,
                  selected: stage == current,
                  onTap: () => Navigator.of(ctx).pop(stage),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _onSetCastingProjectStage({
  required WidgetRef ref,
  required BuildContext context,
  required AppLocalizations t,
  required CastingModel casting,
}) async {
  final next = await _showCastingStagePicker(
    context: context,
    current: casting.projectStage,
  );
  if (!context.mounted || next == null || next == casting.projectStage) return;

  try {
    await ref
        .read(castingsServiceProvider)
        .setProjectStage(castingId: casting.id, stage: next);
    await AdminActionLogService(Supabase.instance.client).log(
      actionType: 'casting_stage_updated',
      title: 'Этап кастинга изменен',
      targetTable: 'castings',
      targetId: casting.id,
      targetText: casting.title,
      status: castingProjectStageToString(next),
    );
    ref.invalidate(castingsProvider);
    if (!context.mounted) return;
    _showSnack(
      context,
      _castingLocaleText(
        context,
        'Этап кастинга обновлен',
        'Casting stage updated',
      ),
    );
  } on CastingsException catch (e, st) {
    AppLogger.error(
      'Casting stage update failed',
      error: e.original ?? e,
      stackTrace: st,
    );
    if (!context.mounted) return;
    _showSnack(context, _castingAdminErrorText(e, t));
  } catch (e, st) {
    AppLogger.error('Casting stage update failed', error: e, stackTrace: st);
    if (!context.mounted) return;
    _showSnack(context, _castingAdminErrorText(e, t));
  }
}

Future<void> _onAddCastingReferences({
  required WidgetRef ref,
  required BuildContext context,
  required AppLocalizations t,
  required CastingModel casting,
}) async {
  try {
    final picked = await pickCastingReferenceMedia();
    if (!context.mounted || picked.isEmpty) return;

    _showSnack(
      context,
      _castingLocaleText(
        context,
        'Загружаю референсы...',
        'Uploading references...',
      ),
    );

    final sb = Supabase.instance.client;
    final userId = sb.auth.currentUser?.id.trim() ?? '';
    final uploaded = await uploadCastingReferenceMedia(
      supabase: sb,
      ownerId: userId,
      items: picked,
    );
    if (!context.mounted || uploaded.isEmpty) return;

    final next = <CastingReferenceMedia>[
      ...casting.referenceMedia,
      ...uploaded,
    ];
    await ref
        .read(castingsServiceProvider)
        .setReferenceMedia(castingId: casting.id, referenceMedia: next);
    await AdminActionLogService(Supabase.instance.client).log(
      actionType: 'casting_references_updated',
      title: 'Референсы кастинга обновлены',
      targetTable: 'castings',
      targetId: casting.id,
      targetText: casting.title,
      status: '${next.length}',
    );
    ref.invalidate(castingsProvider);
    if (!context.mounted) return;
    _showSnack(
      context,
      _castingLocaleText(context, 'Референсы добавлены', 'References added'),
    );
  } on CastingsException catch (e, st) {
    AppLogger.error(
      'Casting references update failed',
      error: e.original ?? e,
      stackTrace: st,
    );
    if (!context.mounted) return;
    _showSnack(context, _castingAdminErrorText(e, t));
  } catch (e, st) {
    AppLogger.error(
      'Casting references update failed',
      error: e,
      stackTrace: st,
    );
    if (!context.mounted) return;
    _showSnack(context, _castingAdminErrorText(e, t));
  }
}

class CastingPage extends ConsumerStatefulWidget {
  const CastingPage({super.key});

  @override
  ConsumerState<CastingPage> createState() => _CastingPageState();
}

class _CastingPageState extends ConsumerState<CastingPage> {
  String? _selectedCastingId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final myProfiles = ref.watch(myProfileProvider);
    final castings = ref.watch(castingsProvider);
    final responding = ref.watch(respondingCastingsProvider);
    final responseStatuses = ref.watch(myCastingResponseStatusesProvider);
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);

    final profilesReady = myProfiles.hasValue;
    final profilesLoading = myProfiles.isLoading;
    final profilesError = myProfiles.hasError;
    final responseStatusMap =
        responseStatuses.value ?? const <String, CastingResponseStatus>{};
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _castingsDesktopBreakpoint;
    final pagePadding = isDesktop
        ? _castingsDesktopPadding
        : const EdgeInsets.fromLTRB(
            kPagePadH,
            kPagePadTop,
            kPagePadH,
            kPagePadBottom,
          );

    void respond(String castingId) {
      if (profilesLoading) {
        _showSnack(context, t.loadingDots);
        return;
      }
      if (profilesError) {
        _showSnack(context, t.signInGenericError);
        return;
      }
      _onRespondTap(
        ref: ref,
        context: context,
        t: t,
        myProfiles: myProfiles,
        castingId: castingId,
      );
    }

    void deleteCasting(String castingId) {
      _onDeleteCastingTap(
        ref: ref,
        context: context,
        t: t,
        castingId: castingId,
      );
    }

    void setCastingStage(CastingModel casting) {
      _onSetCastingProjectStage(
        ref: ref,
        context: context,
        t: t,
        casting: casting,
      );
    }

    void addCastingReferences(CastingModel casting) {
      _onAddCastingReferences(
        ref: ref,
        context: context,
        t: t,
        casting: casting,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: kTopBarH,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: kTopBarIconBoxW,
                          child: Center(child: BrandLogo(height: kBrandLogoH)),
                        ),
                        const SizedBox(width: kGap10),
                        Expanded(
                          child: Container(
                            height: kTopBarH,
                            alignment: Alignment.center,
                            padding: kAccountPad,
                            decoration: pillDecoration(
                              isDark: true,
                              radius: BrandTheme.pillRadius,
                            ),
                            child: Text(
                              t.castingsUpper,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: BrandTheme.pillText.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 16,
                                letterSpacing: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: kGap14),
                  Expanded(
                    child: castings.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            BrandTheme.redTop,
                          ),
                        ),
                      ),
                      error: (err, st) {
                        AppLogger.error(
                          'Castings load failed',
                          error: err,
                          stackTrace: st,
                        );
                        final errorText = AppErrorMapper.message(
                          err,
                          t,
                          original: err is CastingsException
                              ? err.original
                              : null,
                        );
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 54,
                                  color: kTextMuted,
                                ),
                                const SizedBox(height: kGap12),
                                Text(
                                  errorText,
                                  style: kCastingBodyStyle.copyWith(
                                    color: kTextMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: kGap12),
                                SizedBox(
                                  height: kLoginButtonH,
                                  child: BrandPillButton(
                                    label: t.retryUpper,
                                    style: BrandPillStyle.dark,
                                    onTap: () =>
                                        ref.invalidate(castingsProvider),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      data: (items) {
                        if (items.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.videocam_off_rounded,
                                    size: 54,
                                    color: kTextMuted,
                                  ),
                                  const SizedBox(height: kGap12),
                                  Text(
                                    t.noCastingsYetUpper,
                                    style: BrandTheme.pillText.copyWith(
                                      color: kTextMuted,
                                      fontSize: 15,
                                      letterSpacing: 1.15,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final selected = items.firstWhere(
                          (item) => item.id == _selectedCastingId,
                          orElse: () => items.first,
                        );
                        if (_selectedCastingId != selected.id) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() => _selectedCastingId = selected.id);
                          });
                        }

                        if (isDesktop) {
                          return _CastingsDesktopLayout(
                            items: items,
                            selected: selected,
                            respondingIds: responding,
                            responseStatusMap: responseStatusMap,
                            profilesReady: profilesReady,
                            isAdmin: isAdmin,
                            onSelect: (casting) {
                              setState(() => _selectedCastingId = casting.id);
                            },
                            onRespondTap: respond,
                            onDeleteTap: isAdmin ? deleteCasting : null,
                            onStageTap: isAdmin ? setCastingStage : null,
                            onReferencesTap: isAdmin
                                ? addCastingReferences
                                : null,
                            onRefresh: () async =>
                                ref.refresh(castingsProvider.future),
                          );
                        }

                        return RefreshIndicator(
                          color: BrandTheme.redTop,
                          backgroundColor: Colors.white,
                          onRefresh: () async =>
                              ref.refresh(castingsProvider.future),
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: kGap12),
                            itemBuilder: (context, index) {
                              final casting = items[index];

                              return CastingCard(
                                casting: casting,
                                isResponding: responding.contains(casting.id),
                                responseStatus: responseStatusMap[casting.id],
                                isDisabled: !profilesReady,
                                onDeleteTap: isAdmin ? deleteCasting : null,
                                onRespondTap: respond,
                              );
                            },
                          ),
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

class _CastingsDesktopLayout extends StatelessWidget {
  const _CastingsDesktopLayout({
    required this.items,
    required this.selected,
    required this.respondingIds,
    required this.responseStatusMap,
    required this.profilesReady,
    required this.isAdmin,
    required this.onSelect,
    required this.onRespondTap,
    required this.onDeleteTap,
    required this.onStageTap,
    required this.onReferencesTap,
    required this.onRefresh,
  });

  final List<CastingModel> items;
  final CastingModel selected;
  final Set<String> respondingIds;
  final Map<String, CastingResponseStatus> responseStatusMap;
  final bool profilesReady;
  final bool isAdmin;
  final ValueChanged<CastingModel> onSelect;
  final ValueChanged<String> onRespondTap;
  final ValueChanged<String>? onDeleteTap;
  final ValueChanged<CastingModel>? onStageTap;
  final ValueChanged<CastingModel>? onReferencesTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final deleteTap = onDeleteTap;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _castingsDesktopMaxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _castingsDesktopListWidth,
              child: _CastingsDesktopQueuePanel(
                items: items,
                selected: selected,
                respondingIds: respondingIds,
                responseStatusMap: responseStatusMap,
                isAdmin: isAdmin,
                onSelect: onSelect,
                onRefresh: onRefresh,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _CastingDesktopDetailPanel(
                casting: selected,
                status: responseStatusMap[selected.id],
                isResponding: respondingIds.contains(selected.id),
                isDisabled: !profilesReady,
                isAdmin: isAdmin,
                onRespondTap: () => onRespondTap(selected.id),
                onStageTap: onStageTap == null
                    ? null
                    : () => onStageTap!(selected),
                onReferencesTap: onReferencesTap == null
                    ? null
                    : () => onReferencesTap!(selected),
                onDeleteTap: deleteTap == null
                    ? null
                    : () => deleteTap(selected.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CastingsDesktopQueuePanel extends StatelessWidget {
  const _CastingsDesktopQueuePanel({
    required this.items,
    required this.selected,
    required this.respondingIds,
    required this.responseStatusMap,
    required this.isAdmin,
    required this.onSelect,
    required this.onRefresh,
  });

  final List<CastingModel> items;
  final CastingModel selected;
  final Set<String> respondingIds;
  final Map<String, CastingResponseStatus> responseStatusMap;
  final bool isAdmin;
  final ValueChanged<CastingModel> onSelect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';

    return Container(
      decoration: castingCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ru ? 'КАСТИНГИ' : 'CASTINGS',
                    style: BrandTheme.pillText.copyWith(
                      color: kTextDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ru
                        ? 'Выберите кастинг, чтобы открыть детали и управление.'
                        : 'Select a casting to view details and manage it.',
                    style: kCastingBodyStyle.copyWith(
                      color: kTextMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 10),
                  Tooltip(
                    message: ru ? 'Создать кастинг' : 'Create casting',
                    child: IconButton.filled(
                      onPressed: () => context.go(Routes.createCastingAdmin),
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: kTextDark,
                        foregroundColor: Colors.white,
                        fixedSize: const Size(38, 38),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: BrandTheme.redTop,
              backgroundColor: Colors.white,
              onRefresh: onRefresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final casting = items[index];
                  return _CastingListTile(
                    casting: casting,
                    selected: selected.id == casting.id,
                    status: responseStatusMap[casting.id],
                    isResponding: respondingIds.contains(casting.id),
                    onTap: () => onSelect(casting),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CastingListTile extends StatelessWidget {
  const _CastingListTile({
    required this.casting,
    required this.selected,
    required this.status,
    required this.isResponding,
    required this.onTap,
  });

  final CastingModel casting;
  final bool selected;
  final CastingResponseStatus? status;
  final bool isResponding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final statusText = isResponding
        ? t.loadingDots
        : (status == null
              ? t.respondUpper
              : castingResponseStatusLabel(t, status!));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: castingCardDecoration().copyWith(
            border: Border.all(
              color: selected
                  ? BrandTheme.redTop.withValues(alpha: 0.58)
                  : Colors.white.withValues(alpha: 0.78),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                casting.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kCastingTitleStyle.copyWith(fontSize: 18),
              ),
              if (casting.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  casting.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: kCastingBodyStyle,
                ),
              ],
              const SizedBox(height: 10),
              _CastingMetaPill(
                icon: castingProjectStageIcon(casting.projectStage),
                label: castingProjectStageLabel(context, casting.projectStage),
                color: castingProjectStageColor(casting.projectStage),
              ),
              if (casting.referenceMedia.isNotEmpty) ...[
                const SizedBox(height: 8),
                _CastingMetaPill(
                  icon: Icons.attach_file_rounded,
                  label: _castingLocaleText(
                    context,
                    'Референсы: ${casting.referenceMedia.length}',
                    'References: ${casting.referenceMedia.length}',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (casting.datesText.isNotEmpty)
                    Expanded(
                      child: _CastingMetaPill(
                        icon: Icons.event_rounded,
                        label: casting.datesText,
                      ),
                    ),
                  if (casting.datesText.isNotEmpty) const SizedBox(width: 8),
                  Flexible(
                    child: _CastingMetaPill(
                      icon: Icons.circle_rounded,
                      label: statusText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CastingDesktopDetailPanel extends StatelessWidget {
  const _CastingDesktopDetailPanel({
    required this.casting,
    required this.status,
    required this.isResponding,
    required this.isDisabled,
    required this.isAdmin,
    required this.onRespondTap,
    required this.onStageTap,
    required this.onReferencesTap,
    required this.onDeleteTap,
  });

  final CastingModel casting;
  final CastingResponseStatus? status;
  final bool isResponding;
  final bool isDisabled;
  final bool isAdmin;
  final VoidCallback onRespondTap;
  final VoidCallback? onStageTap;
  final VoidCallback? onReferencesTap;
  final VoidCallback? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final canRespond = !isResponding && !isDisabled;
    final responseLabel = isResponding
        ? t.loadingDots
        : (status == null
              ? t.respondUpper
              : _castingLocaleText(
                  context,
                  'ДОБАВИТЬ УЧАСТНИКА',
                  'ADD PARTICIPANT',
                ));

    return Container(
      decoration: castingCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _CastingDesktopDetailBody(
                  casting: casting,
                  status: status,
                  wide:
                      constraints.maxWidth >= _castingsDesktopDetailBreakpoint,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 10, 28, 28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final adminActions = isAdmin && onDeleteTap != null;
                final stacked = adminActions && constraints.maxWidth < 880;
                final respondButton = SizedBox(
                  height: BrandTheme.pillHeight,
                  child: BrandPillButton(
                    label: responseLabel,
                    style: BrandPillStyle.dark,
                    onTap: canRespond ? onRespondTap : null,
                  ),
                );

                if (!adminActions) return respondButton;

                final deleteButton = SizedBox(
                  height: BrandTheme.pillHeight,
                  child: BrandPillButton(
                    label: t.deleteUpper,
                    style: BrandPillStyle.light,
                    onTap: onDeleteTap,
                  ),
                );
                final stageButton = SizedBox(
                  height: BrandTheme.pillHeight,
                  child: BrandPillButton(
                    label: _castingLocaleText(context, 'ЭТАП', 'STAGE'),
                    style: BrandPillStyle.light,
                    onTap: onStageTap,
                  ),
                );
                final referencesButton = SizedBox(
                  height: BrandTheme.pillHeight,
                  child: BrandPillButton(
                    label: _castingLocaleText(context, 'РЕФЫ', 'REFS'),
                    style: BrandPillStyle.light,
                    onTap: onReferencesTap,
                  ),
                );
                final responsesButton = SizedBox(
                  height: BrandTheme.pillHeight,
                  child: BrandPillButton(
                    label: _castingLocaleText(context, 'ОТКЛИКИ', 'RESPONSES'),
                    style: BrandPillStyle.light,
                    onTap: () =>
                        context.go('${Routes.adminSelection}/${casting.id}'),
                  ),
                );

                if (stacked) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: deleteButton),
                          const SizedBox(width: 12),
                          Expanded(child: stageButton),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: referencesButton),
                          const SizedBox(width: 12),
                          Expanded(child: responsesButton),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(children: [Expanded(child: respondButton)]),
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(width: 172, child: deleteButton),
                    const SizedBox(width: 12),
                    SizedBox(width: 118, child: stageButton),
                    const SizedBox(width: 12),
                    SizedBox(width: 118, child: referencesButton),
                    const SizedBox(width: 12),
                    SizedBox(width: 174, child: responsesButton),
                    const SizedBox(width: 12),
                    SizedBox(width: 226, child: respondButton),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CastingDesktopDetailBody extends StatelessWidget {
  const _CastingDesktopDetailBody({
    required this.casting,
    required this.status,
    required this.wide,
  });

  final CastingModel casting;
  final CastingResponseStatus? status;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        children: [
          _CastingDetailHeader(casting: casting, status: status),
          const SizedBox(height: 22),
          _CastingDetailTextSections(casting: casting),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 330,
            child: _CastingSummaryPanel(casting: casting, status: status),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _CastingDetailHeader(casting: casting, status: status),
                const SizedBox(height: 22),
                _CastingDetailTextSections(casting: casting),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CastingDetailHeader extends StatelessWidget {
  const _CastingDetailHeader({required this.casting, required this.status});

  final CastingModel casting;
  final CastingResponseStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          casting.title,
          style: kCastingTitleStyle.copyWith(fontSize: 32, height: 1.05),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (casting.datesText.isNotEmpty)
              _CastingInfoChip(
                icon: Icons.event_rounded,
                label: casting.datesText,
              ),
            _CastingInfoChip(
              icon: castingProjectStageIcon(casting.projectStage),
              label: castingProjectStageLabel(context, casting.projectStage),
              color: castingProjectStageColor(casting.projectStage),
            ),
            if (casting.fee.isNotEmpty)
              _CastingInfoChip(
                icon: Icons.payments_rounded,
                label: casting.fee,
              ),
            if (status != null)
              _CastingInfoChip(
                icon: Icons.check_circle_rounded,
                label: castingResponseStatusLabel(t, status!),
              ),
            if (casting.referenceMedia.isNotEmpty)
              _CastingInfoChip(
                icon: Icons.attach_file_rounded,
                label: _castingLocaleText(
                  context,
                  'Референсы: ${casting.referenceMedia.length}',
                  'References: ${casting.referenceMedia.length}',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CastingSummaryPanel extends StatelessWidget {
  const _CastingSummaryPanel({required this.casting, required this.status});

  final CastingModel casting;
  final CastingResponseStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final statusText = status == null
        ? _castingLocaleText(context, 'ОТКЛИК НЕ ОТПРАВЛЕН', 'NOT SUBMITTED')
        : castingResponseStatusLabel(t, status!);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CastingSummaryTile(
            icon: castingProjectStageIcon(casting.projectStage),
            label: _castingLocaleText(context, 'Этап проекта', 'Project stage'),
            value: castingProjectStageLabel(context, casting.projectStage),
            color: castingProjectStageColor(casting.projectStage),
          ),
          const SizedBox(height: 12),
          _CastingSummaryTile(
            icon: Icons.circle_rounded,
            label: _castingLocaleText(context, 'Отклик', 'Response'),
            value: statusText,
          ),
          const SizedBox(height: 12),
          _CastingSummaryTile(
            icon: Icons.attach_file_rounded,
            label: _castingLocaleText(context, 'Референсы', 'References'),
            value: casting.referenceMedia.isEmpty
                ? _castingLocaleText(context, 'Нет', 'None')
                : '${casting.referenceMedia.length}',
          ),
          if (casting.datesText.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CastingSummaryTile(
              icon: Icons.event_rounded,
              label: _castingLocaleText(context, 'Даты', 'Dates'),
              value: casting.datesText,
            ),
          ],
          if (casting.fee.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CastingSummaryTile(
              icon: Icons.payments_rounded,
              label: _castingLocaleText(context, 'Гонорар', 'Fee'),
              value: casting.fee,
            ),
          ],
          if (casting.rights.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CastingSummaryTile(
              icon: Icons.copyright_rounded,
              label: _castingLocaleText(context, 'Права', 'Rights'),
              value: casting.rights,
            ),
          ],
          const Spacer(),
          Text(
            _castingLocaleText(
              context,
              'Детали выбранного кастинга отображаются справа.',
              'Selected casting details are shown on the right.',
            ),
            style: kCastingBodyStyle.copyWith(
              color: kTextMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CastingSummaryTile extends StatelessWidget {
  const _CastingSummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.color = BrandTheme.redTop,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: BrandTheme.pillText.copyWith(
                    color: kTextMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: kCastingBodyStyle.copyWith(
                    color: kTextDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
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

class _CastingDetailTextSections extends StatelessWidget {
  const _CastingDetailTextSections({required this.casting});

  final CastingModel casting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (casting.description.isNotEmpty)
          _CastingDetailSection(
            title: _castingLocaleText(context, 'Описание', 'Description'),
            text: casting.description,
          ),
        if (casting.rights.isNotEmpty) ...[
          const SizedBox(height: 18),
          _CastingDetailSection(
            title: _castingLocaleText(context, 'Права', 'Rights'),
            text: casting.rights,
          ),
        ],
        if (casting.fee.isNotEmpty) ...[
          const SizedBox(height: 18),
          _CastingDetailSection(
            title: _castingLocaleText(context, 'Гонорар', 'Fee'),
            text: casting.fee,
          ),
        ],
        if (casting.referenceMedia.isNotEmpty) ...[
          const SizedBox(height: 18),
          _CastingReferenceGallery(items: casting.referenceMedia),
        ],
      ],
    );
  }
}

class _CastingReferenceGallery extends StatelessWidget {
  const _CastingReferenceGallery({required this.items});

  final List<CastingReferenceMedia> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _castingLocaleText(context, 'Референсы', 'References').toUpperCase(),
          style: BrandTheme.pillText.copyWith(
            color: kTextDark,
            fontSize: 13,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720
                ? 3
                : (constraints.maxWidth >= 460 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.22,
              ),
              itemBuilder: (context, index) =>
                  _CastingReferenceTile(item: items[index]),
            );
          },
        ),
      ],
    );
  }
}

class _CastingReferenceTile extends StatelessWidget {
  const _CastingReferenceTile({required this.item});

  final CastingReferenceMedia item;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final label = item.name.trim().isEmpty
        ? castingReferenceMediaKindLabel(item.kind, isRu: isRu)
        : item.name.trim();
    final icon = switch (item.kind) {
      CastingReferenceMediaKind.image => Icons.image_rounded,
      CastingReferenceMediaKind.video => Icons.videocam_rounded,
      CastingReferenceMediaKind.file => Icons.insert_drive_file_rounded,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final opened = await openExternalUrl(item.url);
          if (!opened && context.mounted) {
            _showSnack(
              context,
              _castingLocaleText(
                context,
                'Открытие файлов доступно в web-версии',
                'Opening files is available on web',
              ),
            );
          }
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.kind == CastingReferenceMediaKind.image)
                CachedNetworkImage(
                  imageUrl: item.url,
                  fit: BoxFit.cover,
                  memCacheWidth: 420,
                  maxWidthDiskCache: 840,
                  placeholder: (_, _) =>
                      Container(color: Colors.black.withValues(alpha: 0.04)),
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_rounded, color: kTextMuted),
                  ),
                )
              else
                Center(child: Icon(icon, size: 44, color: BrandTheme.redTop)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 18, 10, 9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.58),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BrandTheme.pillText.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
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

class _CastingDetailSection extends StatelessWidget {
  const _CastingDetailSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: BrandTheme.pillText.copyWith(
            color: kTextDark,
            fontSize: 13,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: kCastingBodyStyle.copyWith(
            fontSize: 17,
            height: 1.35,
            color: kTextDark,
          ),
        ),
      ],
    );
  }
}

class _CastingInfoChip extends StatelessWidget {
  const _CastingInfoChip({
    required this.icon,
    required this.label,
    this.color = BrandTheme.redTop,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _CastingMetaPill(
      icon: icon,
      label: label,
      color: color,
      large: true,
    );
  }
}

class _CastingMetaPill extends StatelessWidget {
  const _CastingMetaPill({
    required this.icon,
    required this.label,
    this.color = BrandTheme.redTop,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: large ? 320 : 180),
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 10,
        vertical: large ? 10 : 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: large ? 18 : 13, color: color),
          SizedBox(width: large ? 8 : 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kCastingBodyStyle.copyWith(
                fontSize: large ? 14 : 11,
                fontWeight: FontWeight.w800,
                color: kTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CastingStagePickerTile extends StatelessWidget {
  const _CastingStagePickerTile({
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final CastingProjectStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : castingProjectStageColor(stage);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kPillRadius),
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: selected
              ? pillDecoration(isDark: true, radius: kPillRadius)
              : pillDecoration(isDark: false, radius: kPillRadius),
          child: Row(
            children: [
              Icon(castingProjectStageIcon(stage), color: color, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  castingProjectStageLabel(context, stage).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrandTheme.pillText.copyWith(
                    color: color,
                    fontSize: 12,
                    letterSpacing: 0.95,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
