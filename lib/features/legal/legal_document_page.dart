import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import 'legal_documents.dart';

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.kind});

  final LegalDocumentKind kind;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final document = legalDocumentByKind(kind);
    final sections = document.sections(isRu);

    return Scaffold(
      body: Stack(
        children: [
          const BrandBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Row(
                  children: [
                    _IconPill(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        document.title(isRu).toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: BrandTheme.pillText.copyWith(
                          color: kTextDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 56),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kCardRadius),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFFFFF), Color(0xFFF2F2F2)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                    boxShadow: BrandTheme.surfaceShadow(
                      darkColor: Colors.black.withValues(alpha: 0.18),
                      darkBlur: 28,
                      darkOffset: const Offset(0, 14),
                      lightColor: Colors.white.withValues(alpha: 0.72),
                      lightBlur: 18,
                      lightOffset: const Offset(0, -8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu
                            ? 'Версия $kLegalVersion'
                            : 'Version $kLegalVersion',
                        style: _bodyStyle(
                          color: kTextMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isRu
                            ? 'Launch-draft для текущей версии приложения. Документ нужно обновлять при изменении продукта, реквизитов или правил обработки данных.'
                            : 'Launch draft for the current app version. This document should be updated when the product, legal details or data processing rules change.',
                        style: _bodyStyle(
                          color: BrandTheme.redTop,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final section in sections) ...[
                        Text(section.title, style: _titleStyle()),
                        const SizedBox(height: 8),
                        Text(section.body, style: _bodyStyle()),
                        const SizedBox(height: 18),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _titleStyle() {
    return BrandTheme.pillText.copyWith(
      color: kTextDark,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      height: 1.2,
    );
  }

  TextStyle _bodyStyle({
    Color color = kTextDark,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return TextStyle(
      color: color,
      fontSize: 15,
      fontWeight: fontWeight,
      height: 1.35,
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: BrandTheme.lightPillGradient,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: Icon(icon, color: kTextDark, size: 22),
      ),
    );
  }
}
