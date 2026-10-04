import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error_mapper.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'profile_analytics.dart';

TextStyle _analyticsCommandStyle({
  Color color = kTextDark,
  double size = 16,
  double spacing = 1.4,
  FontWeight weight = FontWeight.w600,
}) {
  return BrandTheme.pillText.copyWith(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
  );
}

TextStyle _analyticsBodyStyle({
  Color color = kTextMuted,
  double size = 15,
  double spacing = 0.2,
  FontWeight weight = FontWeight.w600,
  double height = 1.22,
}) {
  return TextStyle(
    color: color,
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
    height: height,
  );
}

class ProfileAnalyticsPage extends ConsumerWidget {
  const ProfileAnalyticsPage({super.key});

  String _hintFor(BuildContext context, ProfileAnalyticsSummary summary) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final hasEvents =
        summary.views > 0 ||
        summary.selectionAdds > 0 ||
        summary.invitations > 0;
    if (hasEvents) {
      return isRu
          ? 'Статистика обновляется по новым просмотрам, подборкам и приглашениям.'
          : 'Stats update from new profile views, selections, and invitations.';
    }
    return isRu
        ? 'Пока новых действий не было. Здесь появятся просмотры, попадания в подборки и приглашения.'
        : 'No new activity yet. Profile views, selections, and invitations will appear here.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(profileAnalyticsProvider);

    if (kIsWeb) {
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      return SettingsPageV2(
        title: ru ? 'Аналитика' : 'Analytics',
        subtitle: ru
            ? 'Просмотры анкет, попадания в подборки и приглашения'
            : 'Profile views, selection adds and invitations',
        backLabel: ru ? 'Аккаунт' : 'Account',
        onBack: () => context.go(Routes.me),
        actions: [
          IconButton(
            tooltip: ru ? 'Обновить' : 'Refresh',
            onPressed: () => ref.invalidate(profileAnalyticsProvider),
            style: IconButton.styleFrom(foregroundColor: Tokens.textSecondary),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
        children: [
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 24),
              child: SkeletonList(rows: 2),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 24),
              child: SettingsNote(
                text: AppErrorMapper.message(e, t),
                tone: SettingsNoteTone.danger,
              ),
            ),
            data: (summary) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSection(
                  title: ru ? 'За всё время' : 'All time',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 560 ? 4 : 2;
                      final tileWidth =
                          (constraints.maxWidth - 12 * (columns - 1)) / columns;
                      final tiles = [
                        (
                          Icons.badge_outlined,
                          t.analyticsProfiles,
                          summary.profileCount,
                        ),
                        (
                          Icons.visibility_outlined,
                          t.analyticsProfileViews,
                          summary.views,
                        ),
                        (
                          Icons.playlist_add_check_rounded,
                          t.analyticsSelectionAdds,
                          summary.selectionAdds,
                        ),
                        (
                          Icons.mail_outline_rounded,
                          t.analyticsInvitations,
                          summary.invitations,
                        ),
                      ];
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final tile in tiles)
                            SizedBox(
                              width: tileWidth,
                              child: _StatTileV2(
                                icon: tile.$1,
                                label: _sentenceCaseAnalytics(tile.$2),
                                value: tile.$3,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SettingsNote(text: _hintFor(context, summary)),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(kPagePadH),
              child: Column(
                children: [
                  BrandAdminHeader(
                    title: t.analyticsUpper,
                    onBack: () => context.go(Routes.me),
                  ),
                  const SizedBox(height: kGap16),
                  Expanded(
                    child: async.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _MessageCard(
                        text: AppErrorMapper.message(e, t),
                        isError: true,
                      ),
                      data: (summary) => RefreshIndicator(
                        color: kTextDark,
                        onRefresh: () async =>
                            ref.refresh(profileAnalyticsProvider.future),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            _MetricCard(
                              icon: Icons.badge_rounded,
                              title: t.analyticsProfiles,
                              value: summary.profileCount.toString(),
                            ),
                            const SizedBox(height: kGap12),
                            _MetricCard(
                              icon: Icons.visibility_rounded,
                              title: t.analyticsProfileViews,
                              value: summary.views.toString(),
                            ),
                            const SizedBox(height: kGap12),
                            _MetricCard(
                              icon: Icons.playlist_add_check_rounded,
                              title: t.analyticsSelectionAdds,
                              value: summary.selectionAdds.toString(),
                            ),
                            const SizedBox(height: kGap12),
                            _MetricCard(
                              icon: Icons.mail_rounded,
                              title: t.analyticsInvitations,
                              value: summary.invitations.toString(),
                            ),
                            const SizedBox(height: kGap12),
                            _MessageCard(text: _hintFor(context, summary)),
                          ],
                        ),
                      ),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: kLoginCardPad,
      decoration: catalogCardDecoration(),
      child: Row(
        children: [
          Container(
            width: kProfileSummaryImageSize,
            height: kProfileSummaryImageSize,
            decoration: BoxDecoration(
              gradient: BrandTheme.darkPillGradient,
              borderRadius: BorderRadius.circular(kProfileImageRadius),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: kProfileSummaryGap),
          Expanded(
            child: Text(
              title,
              style: _analyticsCommandStyle(
                size: 18,
                spacing: 1.6,
                weight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: _analyticsCommandStyle(
              color: BrandTheme.redTop,
              size: 24,
              spacing: 0.3,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: kLoginCardPad,
      decoration: catalogCardDecoration(),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: _analyticsBodyStyle(
          color: isError ? kTextDanger : kTextMuted,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}


String _sentenceCaseAnalytics(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

class _StatTileV2 extends StatelessWidget {
  const _StatTileV2({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Tokens.textSecondary),
          const SizedBox(height: 14),
          Text(
            '$value',
            style: AppText.h1.copyWith(fontSize: 28, height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: Tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}
