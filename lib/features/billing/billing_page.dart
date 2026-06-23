import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/entitlements_provider.dart';
import '../../core/roles_provider.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

TextStyle _billingCommandStyle({
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

TextStyle _billingBodyStyle({
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

class BillingPage extends ConsumerWidget {
  const BillingPage({super.key});

  String _planTitle(AppLocalizations t, BillingPlan plan) {
    return switch (plan) {
      BillingPlan.free => t.billingPlanFree,
      BillingPlan.modelPro => t.billingPlanModelPro,
      BillingPlan.castingAgentPro => t.billingPlanCastingAgentPro,
      BillingPlan.agencyAdmin => t.billingPlanAgencyAdmin,
    };
  }

  List<String> _currentLimits(AppLocalizations t, AccountEntitlements e) {
    final selectionSize = e.maxProfilesPerSelection == null
        ? t.billingUnlimitedSelectionSize
        : t.billingSelectionSizeLimit(e.maxProfilesPerSelection!);
    final selectionCount = e.maxActiveSelections == null
        ? t.billingUnlimitedSelections
        : t.billingSelectionCountLimit(e.maxActiveSelections!);

    return [
      e.maxPublishedProfiles == null
          ? t.billingUnlimitedProfiles
          : t.billingProfileLimit(e.maxPublishedProfiles!),
      if (e.canUseSelectionChat)
        t.billingChatAndInvitations
      else
        t.billingChatRequiresPro,
      if (e.includedProfileBoosts > 0)
        t.billingProfileBoostsIncluded(e.includedProfileBoosts),
      if (accountRoleCanCreateSelections(e.role)) selectionSize,
      if (accountRoleCanCreateSelections(e.role)) selectionCount,
      if (e.canExportBrandedPdf) t.billingBrandedPdf,
      if (e.canUseAgentFolders) t.billingFoldersAndNotes,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final entitlementsAsync = ref.watch(accountEntitlementsProvider);

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
                children: [
                  BrandAdminHeader(
                    title: t.billingTitleUpper,
                    onBack: () => context.go('/me'),
                  ),
                  const SizedBox(height: kGap16),
                  Expanded(
                    child: entitlementsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => _MessageCard(text: t.unknownError),
                      data: (entitlements) => ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _CurrentPlanCard(
                            title: _planTitle(t, entitlements.plan),
                            status: entitlements.isPaidActive
                                ? t.billingPlanActive
                                : t.billingPlanFreeStatus,
                            features: _currentLimits(t, entitlements),
                          ),
                          const SizedBox(height: kGap12),
                          _PlanCard(
                            title: t.billingPlanFree,
                            subtitle: t.billingFreeSubtitle,
                            features: [
                              t.billingProfileLimit(2),
                              t.billingBasicCatalog,
                              t.billingInvitationsPreview,
                              t.billingChatRequiresPro,
                              t.billingBasicAnalytics,
                            ],
                            active: entitlements.plan == BillingPlan.free,
                          ),
                          const SizedBox(height: kGap12),
                          _PlanCard(
                            title: t.billingPlanModelPro,
                            subtitle: t.billingModelProSubtitle,
                            features: [
                              t.billingProfileLimit(5),
                              t.billingChatAndInvitations,
                              t.billingProfileBoostsIncluded(3),
                              t.billingExpandedMedia,
                              t.billingProBadge,
                              t.billingAnalytics,
                            ],
                            active:
                                entitlements.plan == BillingPlan.modelPro &&
                                entitlements.isPaidActive,
                          ),
                          const SizedBox(height: kGap12),
                          _PlanCard(
                            title: t.billingBoostOneTime,
                            subtitle: t.billingBoostOneTimeSubtitle,
                            features: [
                              t.billingBoostOneTimeFeature,
                              t.billingProfileBoost,
                            ],
                            active: false,
                          ),
                          const SizedBox(height: kGap12),
                          _PlanCard(
                            title: t.billingPlanCastingAgentPro,
                            subtitle: t.billingCastingProSubtitle,
                            features: [
                              t.billingUnlimitedSelections,
                              t.billingUnlimitedSelectionSize,
                              t.billingBrandedPdf,
                              t.billingFoldersAndNotes,
                            ],
                            active:
                                entitlements.plan ==
                                    BillingPlan.castingAgentPro &&
                                entitlements.isPaidActive,
                          ),
                        ],
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

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.title,
    required this.status,
    required this.features,
  });

  final String title;
  final String status;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: pillDecoration(isDark: true, radius: kCardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: _billingCommandStyle(
              color: Colors.white70,
              size: 12,
              spacing: 1.8,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: kGap8),
          Text(
            title,
            style: _billingCommandStyle(
              color: Colors.white,
              size: 24,
              spacing: 0.3,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: kGap12),
          for (final item in features) _FeatureLine(text: item, isDark: true),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.features,
    required this.active,
  });

  final String title;
  final String subtitle;
  final List<String> features;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: catalogCardDecoration().copyWith(
        border: Border.all(
          color: active ? BrandTheme.redTop : kBorderColor,
          width: active ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: _billingCommandStyle(
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: BrandTheme.redTop,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    t.billingCurrentUpper,
                    style: _billingCommandStyle(
                      color: Colors.white,
                      size: 11,
                      spacing: 1.3,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: kGap6),
          Text(subtitle, style: _billingBodyStyle()),
          const SizedBox(height: kGap12),
          for (final item in features) _FeatureLine(text: item),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.text, this.isDark = false});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : kTextDark;
    final muted = isDark ? Colors.white70 : kTextMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_rounded, color: muted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: _billingBodyStyle(color: color, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: catalogCardDecoration(),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: _billingBodyStyle(color: kTextDanger, weight: FontWeight.w700),
      ),
    );
  }
}
