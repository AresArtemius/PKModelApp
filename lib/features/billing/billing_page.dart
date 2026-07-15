import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase_provider.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../profile/my_profile_controller.dart';
import '../profile/profile_model.dart';
import '../legal/legal_documents.dart';

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

const List<_BillingProduct> _billingProducts = [
  _BillingProduct(
    code: 'profile_active_1m',
    months: 1,
    priceRub: 500,
    savingRub: 0,
  ),
  _BillingProduct(
    code: 'profile_active_3m',
    months: 3,
    priceRub: 1400,
    savingRub: 100,
  ),
  _BillingProduct(
    code: 'profile_active_6m',
    months: 6,
    priceRub: 2400,
    savingRub: 600,
  ),
  _BillingProduct(
    code: 'profile_active_12m',
    months: 12,
    priceRub: 4000,
    savingRub: 2000,
  ),
];

final _profileBillingSummaryProvider = FutureProvider.family
    .autoDispose<_ProfileBillingSummary, String>((ref, profileId) async {
      final sb = ref.watch(supabaseProvider);
      final data = await sb.rpc(
        'my_profile_billing_summary',
        params: {'p_profile_id': profileId},
      );
      final rows = data is List ? data : const [];
      if (rows.isEmpty || rows.first is! Map) {
        return const _ProfileBillingSummary.inactive();
      }
      return _ProfileBillingSummary.fromMap(
        Map<String, dynamic>.from(rows.first as Map),
      );
    });

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  String? _selectedProfileId;
  String _selectedProductCode = _billingProducts.first.code;
  String _errorText = '';
  String _infoText = '';
  bool _isSubmitting = false;

  bool get _isRussian {
    final locale = Localizations.maybeLocaleOf(context);
    return locale == null || locale.languageCode.toLowerCase() == 'ru';
  }

  Future<void> _startPayment(MyProfileState profile) async {
    if (_isSubmitting) return;
    if (profile.status != ProfileStatus.approved) {
      setState(() {
        _errorText = _isRussian
            ? 'Оплата доступна после одобрения анкеты модератором.'
            : 'Payment is available after profile approval.';
        _infoText = '';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = '';
      _infoText = '';
    });

    try {
      final sb = ref.read(supabaseProvider);
      final response = await sb.functions.invoke(
        'create-yookassa-payment',
        body: {'profile_id': profile.id, 'product_code': _selectedProductCode},
      );
      final data = response.data;
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      final confirmationUrl = (map?['confirmation_url'] ?? '').toString();
      final error = (map?['error'] ?? '').toString();
      if (error.isNotEmpty) throw Exception(error);
      if (confirmationUrl.isEmpty) {
        throw Exception('YooKassa confirmation_url is empty');
      }

      final opened = await launchUrl(
        Uri.parse(confirmationUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('Could not open YooKassa payment page');
      }

      if (!mounted) return;
      setState(() {
        _infoText = _isRussian
            ? 'Открыли страницу оплаты. После успешной оплаты размещение включится автоматически.'
            : 'Payment page opened. Placement will be activated automatically after payment.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = _paymentErrorText(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _paymentErrorText(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('function not found') ||
        lower.contains('failed to send a request')) {
      return _isRussian
          ? 'Платежная функция еще не развернута в Supabase. Нужно deploy create-yookassa-payment.'
          : 'Payment function is not deployed yet.';
    }
    if (lower.contains('credentials') || lower.contains('yookassa')) {
      return _isRussian
          ? 'ЮKassa еще не настроена на сервере: проверьте SHOP_ID, SECRET_KEY и redeploy Edge Function.'
          : 'YooKassa is not configured on the server.';
    }
    if (lower.contains('billing product not found')) {
      return _isRussian
          ? 'Тариф не найден в базе. Проверьте, что yookassa_billing_flow.sql и profile_billing_mvp.sql применены.'
          : 'Billing product was not found.';
    }
    if (lower.contains('profile not found') ||
        lower.contains('access denied')) {
      return _isRussian
          ? 'Не удалось создать оплату для этой анкеты: нет доступа или анкета не найдена.'
          : 'Could not create payment for this profile.';
    }
    if (error is FunctionException) {
      return _isRussian
          ? 'Ошибка платежной функции: ${error.details ?? error.reasonPhrase ?? error.toString()}'
          : 'Payment function error: ${error.details ?? error.reasonPhrase ?? error.toString()}';
    }
    return _isRussian
        ? 'Не удалось начать оплату: $raw'
        : 'Could not start payment: $raw';
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(myProfileProvider);
    final ru = _isRussian;

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
                    title: ru ? 'РАЗМЕЩЕНИЕ В БАЗЕ' : 'PROFILE PLACEMENT',
                    onBack: () => context.go('/me'),
                  ),
                  const SizedBox(height: kGap12),
                  Expanded(
                    child: profilesAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: kTextDark),
                      ),
                      error: (error, _) => _MessageCard(
                        text: ru
                            ? 'Не удалось загрузить анкеты: $error'
                            : 'Could not load profiles: $error',
                      ),
                      data: (profiles) {
                        final savedProfiles = profiles
                            .where((profile) => profile.id.trim().isNotEmpty)
                            .toList(growable: false);
                        if (savedProfiles.isEmpty) {
                          return _MessageCard(
                            text: ru
                                ? 'Сначала создайте и сохраните анкету. После модерации ее можно будет оплатить и активировать в базе.'
                                : 'Create and save a profile first. After moderation you can pay for placement.',
                          );
                        }

                        final selectedProfile = _selectedProfile(savedProfiles);
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 900;
                            final content = wide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: _ProfilesPanel(
                                          profiles: savedProfiles,
                                          selectedId: selectedProfile.id,
                                          onSelected: (id) => setState(() {
                                            _selectedProfileId = id;
                                            _errorText = '';
                                            _infoText = '';
                                          }),
                                        ),
                                      ),
                                      const SizedBox(width: kGap12),
                                      Expanded(
                                        flex: 4,
                                        child: _PaymentPanel(
                                          profile: selectedProfile,
                                          selectedProductCode:
                                              _selectedProductCode,
                                          onProductSelected: (code) => setState(
                                            () => _selectedProductCode = code,
                                          ),
                                          onPay: _isSubmitting
                                              ? null
                                              : () => _startPayment(
                                                  selectedProfile,
                                                ),
                                          isSubmitting: _isSubmitting,
                                          errorText: _errorText,
                                          infoText: _infoText,
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView(
                                    padding: EdgeInsets.zero,
                                    children: [
                                      _ProfilesPanel(
                                        profiles: savedProfiles,
                                        selectedId: selectedProfile.id,
                                        onSelected: (id) => setState(() {
                                          _selectedProfileId = id;
                                          _errorText = '';
                                          _infoText = '';
                                        }),
                                      ),
                                      const SizedBox(height: kGap12),
                                      _PaymentPanel(
                                        profile: selectedProfile,
                                        selectedProductCode:
                                            _selectedProductCode,
                                        onProductSelected: (code) => setState(
                                          () => _selectedProductCode = code,
                                        ),
                                        onPay: _isSubmitting
                                            ? null
                                            : () => _startPayment(
                                                selectedProfile,
                                              ),
                                        isSubmitting: _isSubmitting,
                                        errorText: _errorText,
                                        infoText: _infoText,
                                      ),
                                    ],
                                  );

                            return Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1180,
                                ),
                                child: content,
                              ),
                            );
                          },
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

  MyProfileState _selectedProfile(List<MyProfileState> profiles) {
    final selectedId = _selectedProfileId;
    if (selectedId != null) {
      for (final profile in profiles) {
        if (profile.id == selectedId) return profile;
      }
    }
    return profiles.firstWhere(
      (profile) => profile.status == ProfileStatus.approved,
      orElse: () => profiles.first,
    );
  }
}

class _ProfilesPanel extends StatelessWidget {
  const _ProfilesPanel({
    required this.profiles,
    required this.selectedId,
    required this.onSelected,
  });

  final List<MyProfileState> profiles;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ru = _isRu(context);
    return _BillingSection(
      title: ru ? 'Выберите анкету' : 'Choose profile',
      subtitle: ru
          ? 'Оплата включает активное размещение одной анкеты в базе.'
          : 'Payment activates placement for one profile.',
      child: Column(
        children: [
          for (var i = 0; i < profiles.length; i++) ...[
            _ProfileChoiceCard(
              profile: profiles[i],
              selected: profiles[i].id == selectedId,
              onTap: () => onSelected(profiles[i].id),
            ),
            if (i != profiles.length - 1) const SizedBox(height: kGap8),
          ],
        ],
      ),
    );
  }
}

class _PaymentPanel extends ConsumerWidget {
  const _PaymentPanel({
    required this.profile,
    required this.selectedProductCode,
    required this.onProductSelected,
    required this.onPay,
    required this.isSubmitting,
    required this.errorText,
    required this.infoText,
  });

  final MyProfileState profile;
  final String selectedProductCode;
  final ValueChanged<String> onProductSelected;
  final VoidCallback? onPay;
  final bool isSubmitting;
  final String errorText;
  final String infoText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = _isRu(context);
    final statusAsync = ref.watch(_profileBillingSummaryProvider(profile.id));
    final canPay = profile.status == ProfileStatus.approved;
    final selectedProduct = _billingProducts.firstWhere(
      (item) => item.code == selectedProductCode,
      orElse: () => _billingProducts.first,
    );

    return _BillingSection(
      title: ru ? 'Срок размещения' : 'Placement period',
      subtitle: ru
          ? 'После оплаты анкета автоматически станет активной до конца периода.'
          : 'After payment the profile will be active until the period ends.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          statusAsync.when(
            loading: () => _StatusLine(
              text: ru ? 'Проверяем статус...' : 'Checking status...',
            ),
            error: (error, _) => _StatusLine(
              text: ru
                  ? 'Статус размещения пока недоступен. Проверьте SQL billing layer.'
                  : 'Placement status is unavailable. Check billing SQL layer.',
              danger: true,
            ),
            data: (summary) => _StatusLine(text: summary.label(ru)),
          ),
          const SizedBox(height: kGap12),
          Wrap(
            spacing: kGap8,
            runSpacing: kGap8,
            children: [
              for (final product in _billingProducts)
                _ProductChip(
                  product: product,
                  selected: product.code == selectedProductCode,
                  onTap: () => onProductSelected(product.code),
                ),
            ],
          ),
          const SizedBox(height: kGap14),
          _CheckoutSummary(product: selectedProduct),
          if (!canPay) ...[
            const SizedBox(height: kGap10),
            _InlineMessage(
              text: ru
                  ? 'Сейчас оплатить нельзя: анкета должна быть утверждена.'
                  : 'Payment is disabled until the profile is approved.',
              danger: true,
            ),
          ],
          if (errorText.isNotEmpty) ...[
            const SizedBox(height: kGap10),
            _InlineMessage(text: errorText, danger: true),
          ],
          if (infoText.isNotEmpty) ...[
            const SizedBox(height: kGap10),
            _InlineMessage(text: infoText),
          ],
          const SizedBox(height: kGap14),
          _PayButton(
            label: isSubmitting
                ? (ru ? 'СОЗДАЕМ ОПЛАТУ...' : 'CREATING PAYMENT...')
                : (ru ? 'ПЕРЕЙТИ К ОПЛАТЕ' : 'GO TO PAYMENT'),
            onTap: canPay && !isSubmitting ? onPay : null,
          ),
          const SizedBox(height: kGap10),
          _PaymentLegalLinks(ru: ru),
        ],
      ),
    );
  }
}

class _PaymentLegalLinks extends StatelessWidget {
  const _PaymentLegalLinks({required this.ru});

  final bool ru;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: kGap10,
      runSpacing: kGap6,
      children: [
        _PaymentLegalLink(
          label: ru ? 'Условия' : 'Terms',
          route: legalDocumentByKind(LegalDocumentKind.terms).route,
        ),
        _PaymentLegalLink(
          label: ru ? 'Реквизиты' : 'Legal details',
          route: legalDocumentByKind(LegalDocumentKind.requisites).route,
        ),
      ],
    );
  }
}

class _PaymentLegalLink extends StatelessWidget {
  const _PaymentLegalLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Text(
          label,
          style: _billingBodyStyle(
            color: BrandTheme.redTop,
            size: 12,
            weight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BillingSection extends StatelessWidget {
  const _BillingSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: catalogCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: _billingCommandStyle(
              size: 17,
              spacing: 2,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: kGap4),
          Text(subtitle, style: _billingBodyStyle(size: 14)),
          const SizedBox(height: kGap14),
          child,
        ],
      ),
    );
  }
}

class _ProfileChoiceCard extends StatelessWidget {
  const _ProfileChoiceCard({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final MyProfileState profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ru = _isRu(context);
    final title = profile.fullName.trim().isEmpty
        ? (ru ? 'Анкета без имени' : 'Untitled profile')
        : profile.fullName.trim();
    final subtitle = [
      _roleLabel(profile.effectiveProfileRoles.first, ru),
      if (profile.city.trim().isNotEmpty) profile.city.trim(),
      _profileStatusLabel(profile.status, ru),
    ].join(' • ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? BrandTheme.redTop : kBorderColor,
              width: selected ? 1.5 : 1,
            ),
            color: Colors.white.withValues(alpha: 0.82),
          ),
          child: Row(
            children: [
              _ProfileAvatar(profile: profile),
              const SizedBox(width: kGap10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _billingCommandStyle(
                        size: 16,
                        spacing: 0.3,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _billingBodyStyle(size: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: kGap8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? BrandTheme.redTop : kTextMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  final MyProfileState profile;

  @override
  Widget build(BuildContext context) {
    final title = profile.fullName.trim();
    final initials = title.isEmpty
        ? 'PK'
        : title
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part.characters.first.toUpperCase())
              .join();
    final cover = profile.coverPhotoUrl.trim();

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: BrandTheme.darkPillGradient,
      ),
      clipBehavior: Clip.antiAlias,
      child: cover.isEmpty
          ? Center(
              child: Text(
                initials,
                style: _billingCommandStyle(color: Colors.white, size: 14),
              ),
            )
          : Image.network(
              cover,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  initials,
                  style: _billingCommandStyle(color: Colors.white, size: 14),
                ),
              ),
            ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final _BillingProduct product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ru = _isRu(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected ? BrandTheme.darkPillGradient : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.88),
          border: selected ? null : Border.all(color: kBorderColor),
          boxShadow: selected ? BrandTheme.basePillShadow(isDark: true) : null,
        ),
        child: Text(
          product.periodLabel(ru),
          style: _billingCommandStyle(
            color: selected ? Colors.white : kTextDark,
            size: 13,
            spacing: 1.1,
            weight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({required this.product});

  final _BillingProduct product;

  @override
  Widget build(BuildContext context) {
    final ru = _isRu(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorderColor),
        gradient: BrandTheme.lightPillGradient,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.priceLabel,
                  style: _billingCommandStyle(
                    size: 22,
                    spacing: 0,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  product.monthlyLabel(ru),
                  style: _billingBodyStyle(size: 13),
                ),
              ],
            ),
          ),
          if (product.savingRub > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: BrandTheme.redTop,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                ru
                    ? 'ВЫГОДА ${product.savingRub} ₽'
                    : 'SAVE ${product.savingRub} ₽',
                style: _billingCommandStyle(
                  color: Colors.white,
                  size: 10,
                  spacing: 1,
                  weight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.48,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: BrandTheme.redPillGradient,
            boxShadow: BrandTheme.basePillShadow(isDark: true),
          ),
          child: Text(
            label,
            style: _billingCommandStyle(
              color: Colors.white,
              size: 13,
              spacing: 1.8,
              weight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          danger ? Icons.error_outline_rounded : Icons.verified_user_outlined,
          color: danger ? kTextDanger : kTextMuted,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: _billingBodyStyle(
              color: danger ? kTextDanger : kTextMuted,
              size: 13,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: danger ? BrandTheme.redTop : kBorderColor),
        color: Colors.white.withValues(alpha: 0.72),
      ),
      child: Text(
        text,
        style: _billingBodyStyle(
          color: danger ? kTextDanger : kTextMuted,
          size: 13,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(16),
        decoration: catalogCardDecoration(),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: _billingBodyStyle(color: kTextDanger, weight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _BillingProduct {
  const _BillingProduct({
    required this.code,
    required this.months,
    required this.priceRub,
    required this.savingRub,
  });

  final String code;
  final int months;
  final int priceRub;
  final int savingRub;

  String get priceLabel => '$priceRub ₽';

  String periodLabel(bool ru) {
    if (!ru) return months == 1 ? '1 MONTH' : '$months MONTHS';
    if (months == 1) return '1 МЕСЯЦ';
    if (months == 3) return '3 МЕСЯЦА';
    if (months == 6) return '6 МЕСЯЦЕВ';
    return '1 ГОД';
  }

  String monthlyLabel(bool ru) {
    final perMonth = (priceRub / months).round();
    return ru ? '$perMonth ₽ в месяц' : '$perMonth ₽ per month';
  }
}

class _ProfileBillingSummary {
  const _ProfileBillingSummary({
    required this.status,
    required this.source,
    required this.currentPeriodEnd,
    required this.isActive,
    required this.daysLeft,
  });

  const _ProfileBillingSummary.inactive()
    : status = 'inactive',
      source = '',
      currentPeriodEnd = null,
      isActive = false,
      daysLeft = 0;

  final String status;
  final String source;
  final DateTime? currentPeriodEnd;
  final bool isActive;
  final int daysLeft;

  factory _ProfileBillingSummary.fromMap(Map<String, dynamic> map) {
    return _ProfileBillingSummary(
      status: (map['status'] ?? 'inactive').toString(),
      source: (map['source'] ?? '').toString(),
      currentPeriodEnd: DateTime.tryParse(
        (map['current_period_end'] ?? '').toString(),
      )?.toLocal(),
      isActive: map['is_active'] == true,
      daysLeft: map['days_left'] is int
          ? map['days_left'] as int
          : int.tryParse((map['days_left'] ?? '0').toString()) ?? 0,
    );
  }

  String label(bool ru) {
    if (!isActive) {
      return ru ? 'Размещение не активно' : 'Placement is inactive';
    }
    final end = currentPeriodEnd;
    final date = end == null
        ? ''
        : '${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')}.${end.year}';
    final sourceText = source == 'manual'
        ? (ru ? 'ручная активация' : 'manual')
        : source == 'yookassa'
        ? 'ЮKassa'
        : source;
    return ru
        ? 'Активно до $date • осталось $daysLeft дн. • $sourceText'
        : 'Active until $date • $daysLeft days left • $sourceText';
  }
}

bool _isRu(BuildContext context) {
  final locale = Localizations.maybeLocaleOf(context);
  return locale == null || locale.languageCode.toLowerCase() == 'ru';
}

String _profileStatusLabel(ProfileStatus status, bool ru) => switch (status) {
  ProfileStatus.approved => ru ? 'Утверждена' : 'Approved',
  ProfileStatus.pending => ru ? 'На проверке' : 'Pending',
  ProfileStatus.rejected => ru ? 'Отклонена' : 'Rejected',
  ProfileStatus.draft => ru ? 'Черновик' : 'Draft',
};

String _roleLabel(ProfessionalProfileType role, bool ru) => switch (role) {
  ProfessionalProfileType.model => ru ? 'Модель' : 'Model',
  ProfessionalProfileType.actor => ru ? 'Актер' : 'Actor',
  ProfessionalProfileType.photographer => ru ? 'Фотограф' : 'Photographer',
  ProfessionalProfileType.videographer => ru ? 'Видеограф' : 'Videographer',
  ProfessionalProfileType.stylist => ru ? 'Стилист' : 'Stylist',
  ProfessionalProfileType.makeupArtist => ru ? 'Визажист' : 'Makeup artist',
  ProfessionalProfileType.hairStylist => ru ? 'Hair-стилист' : 'Hair stylist',
};
