import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error_mapper.dart';
import '../../core/app_logger.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../profile/my_profile_controller.dart';
import '../profile/profile_model.dart';
import '../../ui/brand/brand_logo.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/brand_pill_button.dart';
import '../../ui/brand/ui_constants.dart';
import '../../core/auth_providers.dart';
import 'casting_response_status.dart';
import 'castings_service.dart';
import 'castings_provider.dart';
import 'casting_card.dart';

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
}) async {
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

  if (profiles.length == 1) {
    final p = profiles.first;
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
                      itemCount: profiles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final p = profiles[i];
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
    await _chooseProfilesAndRespond(
      context: context,
      t: t,
      profiles: profiles,
      service: service,
      userId: userId,
      castingId: castingId,
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

class CastingPage extends ConsumerWidget {
  const CastingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final myProfiles = ref.watch(myProfileProvider);
    final castings = ref.watch(castingsProvider);
    final responding = ref.watch(respondingCastingsProvider);
    final responseStatuses = ref.watch(myCastingResponseStatusesProvider);

    final profilesReady = myProfiles.hasValue;
    final profilesLoading = myProfiles.isLoading;
    final profilesError = myProfiles.hasError;
    final responseStatusMap =
        responseStatuses.value ?? const <String, CastingResponseStatus>{};

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
                                onRespondTap: (castingId) {
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
                                },
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
