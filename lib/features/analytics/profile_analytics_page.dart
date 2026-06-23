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
