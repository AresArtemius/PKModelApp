import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../ui/brand/public_page_frame.dart';
import '../../ui/brand/ui_constants.dart';
import 'legal_documents.dart';

/// One section of a legal / information page.
class LegalSectionV2 {
  const LegalSectionV2({required this.title, required this.body});

  final String title;
  final String body;
}

/// Web layout for the legal and information pages (/privacy, /terms,
/// /cookies, /child-safety, /processing-notice, /requisites,
/// /account-deletion): a 720 px text column on the left gutter, a table of
/// contents on the right, h1/h2 from the type scale and the update date.
class LegalPageV2 extends StatefulWidget {
  const LegalPageV2({
    super.key,
    required this.title,
    required this.sections,
    this.updated,
    this.lead,
    this.currentRoute,
  });

  final String title;
  final List<LegalSectionV2> sections;

  /// Document version as `YYYY-MM-DD`; shown as «Обновлено 15.07.2026».
  final String? updated;

  /// Line under the title (the legal entity, for example).
  final String? lead;

  /// Route of this page, to leave it out of the «other documents» list.
  final String? currentRoute;

  static const double textWidth = 720;
  static const double tocWidth = 240;
  static const double tocBreakpoint = 1180;

  @override
  State<LegalPageV2> createState() => _LegalPageV2State();
}

class _LegalPageV2State extends State<LegalPageV2> {
  final _scroll = ScrollController();
  late List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.sections.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant LegalPageV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sections.length != widget.sections.length) {
      _keys = List.generate(widget.sections.length, (_) => GlobalKey());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpTo(int index) {
    final context = _keys[index].currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  String _updatedLabel(bool ru) {
    final raw = widget.updated?.trim() ?? '';
    final parsed = DateTime.tryParse(raw);
    final text = parsed == null
        ? raw
        : '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
    if (text.isEmpty) return '';
    return ru ? 'Обновлено $text' : 'Updated $text';
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final showToc = width >= LegalPageV2.tocBreakpoint;
    final gutter = wide ? 32.0 : 16.0;
    final updated = _updatedLabel(ru);

    final others = legalDocuments
        .where((d) => d.route != widget.currentRoute)
        .toList(growable: false);
    final showDeletion = widget.currentRoute != Routes.accountDeletion;

    final article = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          widget.title,
          style: AppText.h1.copyWith(fontSize: wide ? 32 : 26),
        ),
        if (updated.isNotEmpty || (widget.lead ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            [
              if ((widget.lead ?? '').isNotEmpty) widget.lead!,
              if (updated.isNotEmpty) updated,
            ].join(' · '),
            style: AppText.small.copyWith(color: Tokens.textSecondary),
          ),
        ],
        if (!showToc && widget.sections.length > 2) ...[
          const SizedBox(height: 24),
          _TocList(
            sections: widget.sections,
            onTap: _jumpTo,
            compact: true,
          ),
        ],
        const SizedBox(height: 32),
        for (var i = 0; i < widget.sections.length; i++) ...[
          KeyedSubtree(
            key: _keys[i],
            child: SelectableText(
              widget.sections[i].title,
              style: AppText.h2.copyWith(fontSize: wide ? 22 : 20),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            widget.sections[i].body,
            style: AppText.body.copyWith(
              fontSize: wide ? 16 : 15,
              height: 1.6,
            ),
          ),
          SizedBox(height: i == widget.sections.length - 1 ? 0 : 32),
        ],
        const SizedBox(height: 40),
        const Divider(height: 1, thickness: 1, color: Tokens.border),
        const SizedBox(height: 20),
        Text(
          (ru ? 'Другие документы' : 'Other documents').toUpperCase(),
          style: AppText.label.copyWith(color: Tokens.textTertiary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            for (final doc in others)
              _DocLink(label: doc.title(ru), route: doc.route),
            if (showDeletion)
              _DocLink(
                label: ru ? 'Удаление аккаунта' : 'Account deletion',
                route: Routes.accountDeletion,
              ),
          ],
        ),
      ],
    );

    final content = Padding(
      padding: EdgeInsets.fromLTRB(gutter, wide ? 36 : 20, gutter, 64),
      child: showToc
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: LegalPageV2.textWidth, child: article),
                const SizedBox(width: 64),
                SizedBox(
                  width: LegalPageV2.tocWidth,
                  child: _TocList(sections: widget.sections, onTap: _jumpTo),
                ),
              ],
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LegalPageV2.textWidth,
              ),
              child: article,
            ),
    );

    return PublicPageFrame(
      currentIndex: 3,
      onBack: wide
          ? null
          : () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(Routes.login);
              }
            },
      child: SingleChildScrollView(
        controller: _scroll,
        child: Align(alignment: Alignment.topLeft, child: content),
      ),
    );
  }
}

class _TocList extends StatelessWidget {
  const _TocList({
    required this.sections,
    required this.onTap,
    this.compact = false,
  });

  final List<LegalSectionV2> sections;
  final ValueChanged<int> onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (ru ? 'Содержание' : 'Contents').toUpperCase(),
          style: AppText.label.copyWith(color: Tokens.textTertiary),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < sections.length; i++)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              onTap: () => onTap(i),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: compact ? 5 : 6,
                  horizontal: 4,
                ),
                child: Text(
                  sections[i].title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(
                    color: Tokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DocLink extends StatelessWidget {
  const _DocLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(route),
      style: TextButton.styleFrom(
        foregroundColor: Tokens.text,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        textStyle: AppText.small,
      ),
      child: Text(label),
    );
  }
}
