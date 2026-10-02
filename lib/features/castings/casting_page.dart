import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Left column with the list on desktop.
const double _castingsListWidth = 380;

/// Readable width of the detail column; the panel itself takes the rest.
const double _castingDetailMaxWidth = 880;
const EdgeInsets _castingsDesktopPadding = EdgeInsets.fromLTRB(32, 24, 32, 28);

/// The v2 look (white page, flat cards, sentence case) is the web standard
/// on every width; native apps keep the pill style for now.
const bool _castingsV2 = kIsWeb;

typedef _ReferenceMediaChanged =
    Future<void> Function(
      CastingModel casting,
      List<CastingReferenceMedia> next,
    );

String _castingLocaleText(BuildContext context, String ru, String en) {
  return Localizations.localeOf(context).languageCode == 'ru' ? ru : en;
}

String _castingAdminErrorText(Object error, AppLocalizations t) {
  final source = error is CastingsException ? error.original : error;
  return AppErrorMapper.message(error, t, original: source);
}

void _showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// v2 dialog: title in sentence case, body text, actions right-aligned.
Future<T?> _showCastingDialog<T>(
  BuildContext context, {
  required String title,
  String? body,
  Widget? content,
  required List<Widget> Function(BuildContext ctx) actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: content ??
            (body == null
                ? const SizedBox.shrink()
                : Text(
                    body,
                    style: AppText.small.copyWith(color: Tokens.textSecondary),
                  )),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: actions(ctx),
    ),
  );
}

Future<bool> _showDeleteCastingConfirm(
  BuildContext context,
  AppLocalizations t,
) async {
  final result = await _showCastingDialog<bool>(
    context,
    title: _castingLocaleText(context, 'Удалить кастинг?', 'Delete casting?'),
    body: _castingLocaleText(
      context,
      'Кастинг, отклики и связанные чаты будут удалены.',
      'The casting, responses, and related chats will be deleted.',
    ),
    actions: (ctx) => [
      TextButton(
        onPressed: () => Navigator.of(ctx).pop(false),
        child: Text(t.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(ctx).pop(true),
        style: FilledButton.styleFrom(backgroundColor: Tokens.danger),
        child: Text(_castingLocaleText(context, 'Удалить', 'Delete')),
      ),
    ],
  );
  return result ?? false;
}

Future<void> _showAuthRequiredDialog(
  BuildContext context,
  AppLocalizations t,
) async {
  await _showCastingDialog<void>(
    context,
    title: t.respondAuthRequiredTitle,
    body: t.respondAuthRequiredMessage,
    actions: (ctx) => [
      TextButton(
        onPressed: () => Navigator.of(ctx).pop(),
        child: Text(t.cancel),
      ),
      OutlinedButton(
        onPressed: () {
          Navigator.of(ctx).pop();
          context.go(Routes.register);
        },
        child: Text(_castingLocaleText(context, 'Регистрация', 'Register')),
      ),
      FilledButton(
        onPressed: () {
          Navigator.of(ctx).pop();
          context.go(Routes.login);
        },
        child: Text(t.signIn),
      ),
    ],
  );
}

Future<void> _showRespondSentSnack(
  BuildContext context,
  AppLocalizations t,
) async {
  _showSnack(context, t.respondSentMessage);
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
    await _showCastingDialog<void>(
      context,
      title: t.respondNoProfilesTitle,
      body: t.respondNoProfilesMessage,
      actions: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.go(Routes.me);
          },
          child: Text(
            _castingLocaleText(context, 'Перейти в анкету', 'Go to profile'),
          ),
        ),
      ],
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
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text(t.respondChooseProfilesTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.respondChooseProfilesMessage,
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
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
                            Tokens.radiusMd,
                          ),
                          color: checked ? Tokens.surface : Tokens.bg,
                          border: Border.all(color: Tokens.border),
                        ),
                        child: CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            setState(() {
                              if ((v ?? false) && id.isNotEmpty) {
                                selectedIds.add(id);
                              } else {
                                selectedIds.remove(id);
                              }
                            });
                          },
                          title: Text(title, style: AppText.small),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Tokens.radiusMd,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () {
                      didConfirm = true;
                      selectedToSend = selectedIds.toList(growable: false);
                      Navigator.of(ctx).pop();
                    },
              child: Text(t.respond),
            ),
          ],
        );
      },
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
  final t = AppLocalizations.of(context)!;
  return _showCastingDialog<CastingProjectStage>(
    context,
    title: t.castingProjectStageLabel,
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final stage in CastingProjectStage.values) ...[
            Builder(
              builder: (ctx) => _CastingStagePickerTile(
                stage: stage,
                selected: stage == current,
                onTap: () => Navigator.of(ctx).pop(stage),
              ),
            ),
            if (stage != CastingProjectStage.values.last)
              const SizedBox(height: 6),
          ],
        ],
      ),
    ),
    actions: (ctx) => [
      TextButton(
        onPressed: () => Navigator.of(ctx).pop(),
        child: Text(t.cancel),
      ),
    ],
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
    final v2 = isDesktop || _castingsV2;

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

    Future<void> updateCastingReferences(
      CastingModel casting,
      List<CastingReferenceMedia> next,
    ) async {
      try {
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

    void openCreateCasting() {
      context.go('${Routes.createCastingAdmin}?from=castings');
    }

    // States other than the loaded list sit inside the page paddings; the
    // desktop list/detail layout owns the whole area itself.
    Widget padded(Widget child) => Padding(
      padding: isDesktop
          ? _castingsDesktopPadding
          : const EdgeInsets.fromLTRB(
              kPagePadH,
              kPagePadTop,
              kPagePadH,
              kPagePadBottom,
            ),
      child: child,
    );

    final body = castings.when(
      loading: () => padded(
        const SkeletonList(rows: 5, leadingSize: 72),
      ),
      error: (err, st) {
        AppLogger.error('Castings load failed', error: err, stackTrace: st);
        final errorText = AppErrorMapper.message(
          err,
          t,
          original: err is CastingsException ? err.original : null,
        );
        return padded(
          _CastingsEmptyState(
            icon: Icons.cloud_off_rounded,
            title: errorText,
            hint: '',
            actionLabel: _castingLocaleText(context, 'Повторить', 'Retry'),
            onAction: () => ref.invalidate(castingsProvider),
          ),
        );
      },
      data: (items) {
        if (items.isEmpty) {
          final signedIn = ref.watch(isAuthenticatedProvider);
          return padded(
            _CastingsEmptyState(
              title: t.castingsEmptyTitle,
              hint: t.castingsEmptyHint,
              actionLabel: signedIn
                  ? t.castingsEmptyNotifyAction
                  : t.castingsEmptySignInAction,
              onAction: () => context.push(
                signedIn ? Routes.notifications : Routes.login,
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
            onCreateTap: isAdmin ? openCreateCasting : null,
            onRespondTap: respond,
            onDeleteTap: isAdmin ? deleteCasting : null,
            onStageTap: isAdmin ? setCastingStage : null,
            onReferencesTap: isAdmin ? addCastingReferences : null,
            onReferenceMediaChanged: isAdmin ? updateCastingReferences : null,
            onRefresh: () async => ref.refresh(castingsProvider.future),
          );
        }

        return RefreshIndicator(
          color: BrandTheme.redTop,
          backgroundColor: Colors.white,
          onRefresh: () async => ref.refresh(castingsProvider.future),
          child: ListView.separated(
            padding: v2
                ? const EdgeInsets.fromLTRB(16, 4, 16, 24)
                : EdgeInsets.zero,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: kGap12),
            itemBuilder: (context, index) {
              final casting = items[index];
              if (v2) {
                return _CastingMobileCard(
                  casting: casting,
                  status: responseStatusMap[casting.id],
                  isResponding: responding.contains(casting.id),
                  isDisabled: !profilesReady,
                  onRespondTap: () => respond(casting.id),
                  onDeleteTap: isAdmin ? () => deleteCasting(casting.id) : null,
                );
              }
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
    );

    if (isDesktop) {
      // The shell's top bar already names the section; the page starts
      // straight with the list and the detail.
      return Scaffold(backgroundColor: Tokens.bg, body: body);
    }

    if (v2) {
      return Scaffold(
        backgroundColor: Tokens.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CastingsMobileHeader(
                count: castings.value?.length,
                onCreateTap: isAdmin ? openCreateCasting : null,
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
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
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile web header: section title, counter and the admin «create» button.
class _CastingsMobileHeader extends StatelessWidget {
  const _CastingsMobileHeader({required this.count, required this.onCreateTap});

  final int? count;
  final VoidCallback? onCreateTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        children: [
          const BrandLogo(height: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.castingsTab, style: AppText.h1),
                if (count != null) ...[
                  const SizedBox(height: 2),
                  Text(t.castingsCount(count!), style: AppText.caption),
                ],
              ],
            ),
          ),
          if (onCreateTap != null)
            IconButton.filled(
              tooltip: t.createCasting,
              onPressed: onCreateTap,
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Tokens.ink,
                foregroundColor: Tokens.textOnDark,
                fixedSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tokens.radiusMd),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mobile web card (v2): everything about the casting plus one action.
class _CastingMobileCard extends StatelessWidget {
  const _CastingMobileCard({
    required this.casting,
    required this.status,
    required this.isResponding,
    required this.isDisabled,
    required this.onRespondTap,
    required this.onDeleteTap,
  });

  final CastingModel casting;
  final CastingResponseStatus? status;
  final bool isResponding;
  final bool isDisabled;
  final VoidCallback onRespondTap;
  final VoidCallback? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final canRespond = !isResponding && !isDisabled;
    final actionLabel = isResponding
        ? t.loadingDots
        : (status == null ? t.respond : t.addParticipant);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tokens.bg,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(casting.title, style: AppText.h2),
          const SizedBox(height: 10),
          _CastingMetaRow(casting: casting, status: status),
          if (casting.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              casting.description,
              style: AppText.small.copyWith(color: Tokens.textSecondary),
            ),
          ],
          if (casting.rights.isNotEmpty) ...[
            const SizedBox(height: 10),
            _CastingInlineFact(label: t.rights, value: casting.rights),
          ],
          if (casting.referenceMedia.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CastingReferencePreviewStrip(items: casting.referenceMedia),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: canRespond ? onRespondTap : null,
                  child: Text(actionLabel),
                ),
              ),
              if (onDeleteTap != null) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: _castingLocaleText(context, 'Удалить', 'Delete'),
                  onPressed: onDeleteTap,
                  icon: const Icon(Icons.delete_outline_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: Tokens.danger,
                    fixedSize: const Size(46, 46),
                    side: const BorderSide(color: Tokens.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Tokens.radiusMd),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// «Label: value» line for secondary facts (rights) on compact cards.
class _CastingInlineFact extends StatelessWidget {
  const _CastingInlineFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: AppText.small.copyWith(color: Tokens.textSecondary),
          ),
          TextSpan(text: value, style: AppText.small),
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
    required this.onCreateTap,
    required this.onRespondTap,
    required this.onDeleteTap,
    required this.onStageTap,
    required this.onReferencesTap,
    required this.onReferenceMediaChanged,
    required this.onRefresh,
  });

  final List<CastingModel> items;
  final CastingModel selected;
  final Set<String> respondingIds;
  final Map<String, CastingResponseStatus> responseStatusMap;
  final bool profilesReady;
  final bool isAdmin;
  final ValueChanged<CastingModel> onSelect;
  final VoidCallback? onCreateTap;
  final ValueChanged<String> onRespondTap;
  final ValueChanged<String>? onDeleteTap;
  final ValueChanged<CastingModel>? onStageTap;
  final ValueChanged<CastingModel>? onReferencesTap;
  final _ReferenceMediaChanged? onReferenceMediaChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final deleteTap = onDeleteTap;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _castingsListWidth,
          child: _CastingsDesktopQueuePanel(
            items: items,
            selected: selected,
            respondingIds: respondingIds,
            responseStatusMap: responseStatusMap,
            onCreateTap: onCreateTap,
            onSelect: onSelect,
            onRefresh: onRefresh,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: Tokens.border),
        Expanded(
          child: _CastingDesktopDetailPanel(
            casting: selected,
            status: responseStatusMap[selected.id],
            isResponding: respondingIds.contains(selected.id),
            isDisabled: !profilesReady,
            isAdmin: isAdmin,
            onRespondTap: () => onRespondTap(selected.id),
            onStageTap: onStageTap == null ? null : () => onStageTap!(selected),
            onReferencesTap: onReferencesTap == null
                ? null
                : () => onReferencesTap!(selected),
            onReferenceMediaChanged: onReferenceMediaChanged,
            onDeleteTap: deleteTap == null ? null : () => deleteTap(selected.id),
          ),
        ),
      ],
    );
  }
}

class _CastingsDesktopQueuePanel extends StatelessWidget {
  const _CastingsDesktopQueuePanel({
    required this.items,
    required this.selected,
    required this.respondingIds,
    required this.responseStatusMap,
    required this.onCreateTap,
    required this.onSelect,
    required this.onRefresh,
  });

  final List<CastingModel> items;
  final CastingModel selected;
  final Set<String> respondingIds;
  final Map<String, CastingResponseStatus> responseStatusMap;
  final VoidCallback? onCreateTap;
  final ValueChanged<CastingModel> onSelect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.castingsTab, style: AppText.h1),
                    const SizedBox(height: 2),
                    Text(t.castingsCount(items.length), style: AppText.caption),
                  ],
                ),
              ),
              if (onCreateTap != null)
                Tooltip(
                  message: t.createCasting,
                  child: IconButton.filled(
                    onPressed: onCreateTap,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Tokens.ink,
                      foregroundColor: Tokens.textOnDark,
                      fixedSize: const Size(40, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Tokens.radiusMd),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: Tokens.accent,
            backgroundColor: Tokens.bg,
            onRefresh: onRefresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
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
    );
  }
}

/// One row of the desktop list: title, a line of context and the stage.
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
    final stageColor = castingProjectStageColor(casting.projectStage);
    final meta = [
      castingProjectStageLabel(context, casting.projectStage),
      if (casting.datesText.isNotEmpty) casting.datesText,
    ].join(' · ');

    return Material(
      color: selected ? Tokens.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        hoverColor: Tokens.surfaceAlt.withValues(alpha: 0.6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      casting.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(height: 1.3),
                    ),
                  ),
                  if (isResponding || status != null) ...[
                    const SizedBox(width: 10),
                    _CastingStatusBadge(
                      label: isResponding
                          ? t.loadingDots
                          : castingResponseStatusLabel(t, status!),
                      color: isResponding
                          ? Tokens.textSecondary
                          : castingResponseStatusColor(status!),
                    ),
                  ],
                ],
              ),
              if (casting.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  casting.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: stageColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ),
                  if (casting.referenceMedia.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.attach_file_rounded,
                      size: 14,
                      color: Tokens.textTertiary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${casting.referenceMedia.length}',
                      style: AppText.caption,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small coloured status (my response) chip.
class _CastingStatusBadge extends StatelessWidget {
  const _CastingStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
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
    required this.onReferenceMediaChanged,
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
  final _ReferenceMediaChanged? onReferenceMediaChanged;
  final VoidCallback? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final canRespond = !isResponding && !isDisabled;
    final responseLabel = isResponding
        ? t.loadingDots
        : (status == null ? t.respond : t.addParticipant);
    final adminActions = isAdmin && onDeleteTap != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _castingDetailMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CastingDetailHeader(casting: casting, status: status),
                    const SizedBox(height: 28),
                    _CastingDetailTextSections(
                      casting: casting,
                      onReferenceMediaChanged: onReferenceMediaChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Tokens.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 16, 40, 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                onPressed: canRespond ? onRespondTap : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, Tokens.controlHeight),
                ),
                child: Text(responseLabel),
              ),
              if (adminActions) ...[
                OutlinedButton.icon(
                  onPressed: () => context.go(
                    '${Routes.adminSelection}/${casting.id}?from=castings',
                  ),
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                  label: Text(t.castingResponsesAction),
                ),
                OutlinedButton.icon(
                  onPressed: onStageTap,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(t.castingStageAction),
                ),
                OutlinedButton.icon(
                  onPressed: onReferencesTap,
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: Text(t.castingReferencesLabel),
                ),
                TextButton.icon(
                  onPressed: onDeleteTap,
                  style: TextButton.styleFrom(foregroundColor: Tokens.danger),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(_castingLocaleText(context, 'Удалить', 'Delete')),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CastingDetailHeader extends StatelessWidget {
  const _CastingDetailHeader({required this.casting, required this.status});

  final CastingModel casting;
  final CastingResponseStatus? status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(casting.title, style: AppText.display.copyWith(fontSize: 32)),
        const SizedBox(height: 16),
        _CastingMetaRow(casting: casting, status: status),
      ],
    );
  }
}

/// Stage, dates, fee, my response and the number of references as chips.
class _CastingMetaRow extends StatelessWidget {
  const _CastingMetaRow({required this.casting, required this.status});

  final CastingModel casting;
  final CastingResponseStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CastingMetaPill(
          icon: castingProjectStageIcon(casting.projectStage),
          label: castingProjectStageLabel(context, casting.projectStage),
          color: castingProjectStageColor(casting.projectStage),
        ),
        if (casting.datesText.isNotEmpty)
          _CastingMetaPill(icon: Icons.event_rounded, label: casting.datesText),
        if (casting.fee.isNotEmpty)
          _CastingMetaPill(icon: Icons.payments_outlined, label: casting.fee),
        if (status != null)
          _CastingMetaPill(
            icon: Icons.check_circle_outline_rounded,
            label: castingResponseStatusLabel(t, status!),
            color: castingResponseStatusColor(status!),
          ),
        if (casting.referenceMedia.isNotEmpty)
          _CastingMetaPill(
            icon: Icons.attach_file_rounded,
            label: '${t.castingReferencesLabel}: '
                '${casting.referenceMedia.length}',
          ),
      ],
    );
  }
}

class _CastingDetailTextSections extends StatelessWidget {
  const _CastingDetailTextSections({
    required this.casting,
    required this.onReferenceMediaChanged,
  });

  final CastingModel casting;
  final _ReferenceMediaChanged? onReferenceMediaChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (casting.description.isNotEmpty)
          _CastingDetailSection(
            title: t.castingDescriptionLabel,
            text: casting.description,
          ),
        if (casting.rights.isNotEmpty) ...[
          const SizedBox(height: 24),
          _CastingDetailSection(title: t.rights, text: casting.rights),
        ],
        if (casting.fee.isNotEmpty) ...[
          const SizedBox(height: 24),
          _CastingDetailSection(title: t.fee, text: casting.fee),
        ],
        if (casting.referenceMedia.isNotEmpty) ...[
          const SizedBox(height: 24),
          _CastingReferenceGallery(
            casting: casting,
            items: casting.referenceMedia,
            onChanged: onReferenceMediaChanged,
          ),
        ],
      ],
    );
  }
}

class _CastingReferenceGallery extends StatelessWidget {
  const _CastingReferenceGallery({
    required this.casting,
    required this.items,
    required this.onChanged,
  });

  final CastingModel casting;
  final List<CastingReferenceMedia> items;
  final _ReferenceMediaChanged? onChanged;

  Future<void> _save(
    BuildContext context,
    List<CastingReferenceMedia> next,
  ) async {
    final handler = onChanged;
    if (handler == null) return;
    await handler(casting, next);
    if (!context.mounted) return;
    _showSnack(
      context,
      _castingLocaleText(context, 'Референсы обновлены', 'References updated'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final canEdit = onChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CastingSectionLabel(t.castingReferencesLabel),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720
                ? 4
                : (constraints.maxWidth >= 460 ? 3 : 2);
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
              itemBuilder: (context, index) => _CastingReferenceTile(
                item: items[index],
                canEdit: canEdit,
                onDelete: () {
                  final next = List<CastingReferenceMedia>.from(items)
                    ..removeAt(index);
                  _save(context, next);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CastingReferencePreviewStrip extends StatelessWidget {
  const _CastingReferencePreviewStrip({required this.items});

  final List<CastingReferenceMedia> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(4).toList(growable: false);
    final extra = items.length - visible.length;
    return Row(
      children: [
        for (final item in visible) ...[
          _CastingReferencePreviewThumb(item: item),
          const SizedBox(width: 8),
        ],
        if (extra > 0)
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
            ),
            child: Text('+$extra', style: AppText.smallStrong),
          ),
      ],
    );
  }
}

class _CastingReferencePreviewThumb extends StatelessWidget {
  const _CastingReferencePreviewThumb({required this.item});

  final CastingReferenceMedia item;

  @override
  Widget build(BuildContext context) {
    final previewUrl = item.kind == CastingReferenceMediaKind.video
        ? item.previewUrl.trim()
        : item.url.trim();
    final icon = switch (item.kind) {
      CastingReferenceMediaKind.image => Icons.image_outlined,
      CastingReferenceMediaKind.video => Icons.videocam_outlined,
      CastingReferenceMediaKind.file => Icons.insert_drive_file_outlined,
    };
    final hasPreview =
        previewUrl.isNotEmpty && item.kind != CastingReferenceMediaKind.file;
    return Material(
      color: Tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.kind == CastingReferenceMediaKind.image
            ? () => _showCastingReferenceLightbox(context, item)
            : () async {
                await openExternalUrl(item.url);
              },
        child: SizedBox(
          width: 56,
          height: 56,
          child: hasPreview
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: previewUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 180,
                      maxWidthDiskCache: 360,
                      placeholder: (_, _) =>
                          const ColoredBox(color: Tokens.surfaceAlt),
                      errorWidget: (_, _, _) =>
                          Icon(icon, color: Tokens.textSecondary),
                    ),
                    if (item.kind == CastingReferenceMediaKind.video)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                  ],
                )
              : Icon(icon, color: Tokens.textSecondary),
        ),
      ),
    );
  }
}


class _CastingReferenceTile extends StatelessWidget {
  const _CastingReferenceTile({
    required this.item,
    required this.canEdit,
    required this.onDelete,
  });

  final CastingReferenceMedia item;
  final bool canEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final label = item.name.trim().isEmpty
        ? castingReferenceMediaKindLabel(item.kind, isRu: isRu)
        : item.name.trim();
    final icon = switch (item.kind) {
      CastingReferenceMediaKind.image => Icons.image_outlined,
      CastingReferenceMediaKind.video => Icons.videocam_outlined,
      CastingReferenceMediaKind.file => Icons.insert_drive_file_outlined,
    };

    return Material(
      color: Tokens.surface,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          if (item.kind == CastingReferenceMediaKind.image) {
            _showCastingReferenceLightbox(context, item);
            return;
          }
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
                    const ColoredBox(color: Tokens.surfaceAlt),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Tokens.textSecondary,
                  ),
                ),
              )
            else
              Center(child: Icon(icon, size: 36, color: Tokens.textSecondary)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: Colors.white),
                ),
              ),
            ),
            if (canEdit)
              Positioned(
                top: 8,
                right: 8,
                child: _ReferenceTileButton(
                  icon: Icons.close_rounded,
                  enabled: true,
                  onTap: onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _showCastingReferenceLightbox(
  BuildContext context,
  CastingReferenceMedia item,
) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.86),
    builder: (context) {
      return Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Tokens.radiusLg),
                        child: CachedNetworkImage(
                          imageUrl: item.url,
                          fit: BoxFit.contain,
                          placeholder: (_, _) =>
                              const ColoredBox(color: Color(0x22000000)),
                          errorWidget: (_, _, _) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: SafeArea(
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    foregroundColor: Tokens.text,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ReferenceTileButton extends StatelessWidget {
  const _ReferenceTileButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: Tokens.text),
        ),
      ),
    );
  }
}

/// Section label of the detail view (the only uppercase text here).
class _CastingSectionLabel extends StatelessWidget {
  const _CastingSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppText.label);
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
        _CastingSectionLabel(title),
        const SizedBox(height: 8),
        Text(text, style: AppText.body),
      ],
    );
  }
}

/// Flat chip with an icon: stage, dates, fee, status.
class _CastingMetaPill extends StatelessWidget {
  const _CastingMetaPill({
    required this.icon,
    required this.label,
    this.color = Tokens.textSecondary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.smallStrong.copyWith(height: 1.3),
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
    return Material(
      color: selected ? Tokens.ink : Tokens.surface,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        onTap: onTap,
        child: Container(
          height: Tokens.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                castingProjectStageIcon(stage),
                color: selected
                    ? Tokens.textOnDark
                    : castingProjectStageColor(stage),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  castingProjectStageLabel(context, stage),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.smallStrong.copyWith(
                    color: selected ? Tokens.textOnDark : Tokens.text,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  color: Tokens.textOnDark,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty castings list (and the error state): one line and one action.
class _CastingsEmptyState extends StatelessWidget {
  const _CastingsEmptyState({
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.onAction,
    this.icon = Icons.videocam_outlined,
  });

  final String title;
  final String hint;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Tokens.surface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 32, color: Tokens.textSecondary),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.h2,
              ),
              if (hint.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: AppText.small.copyWith(color: Tokens.textSecondary),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, Tokens.controlHeight),
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
