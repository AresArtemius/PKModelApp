import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_compat.dart';
import '../../core/supabase_provider.dart';
import '../../core/admin_action_log_service.dart';
import '../../core/router.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_admin_header.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../castings/castings_provider.dart';
import '../castings/casting_project_stage.dart';
import '../castings/casting_reference_media.dart';
import 'selection_providers.dart';
import 'admin_shell_v2.dart';
import 'admin_style.dart';

const double _createCastingDesktopBreakpoint = 900;

/// Single-column width (narrow screens) and the two-column editor's cap,
/// aligned to the left gutter so the page is used, not a strip in the middle.
const double _createCastingFormWidth = 720;
const double _createCastingMaxWidth = 1600;
const double _createCastingSideWidth = 460;
const double _createCastingTwoColumnBreakpoint = 1100;

class CreateCastingAdminPage extends ConsumerStatefulWidget {
  const CreateCastingAdminPage({super.key});

  @override
  ConsumerState<CreateCastingAdminPage> createState() =>
      _CreateCastingAdminPageState();
}

class _CreateCastingAdminPageState
    extends ConsumerState<CreateCastingAdminPage> {
  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  final _rightsC = TextEditingController();
  final _feeC = TextEditingController();

  final _selectedDates = <DateTime>{};
  final _pendingReferences = <PendingCastingReferenceMedia>[];
  CastingProjectStage _stage = defaultCastingProjectStage;
  bool _creating = false;
  bool _pickingReferences = false;

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _rightsC.dispose();
    _feeC.dispose();
    super.dispose();
  }

  Future<void> _createCasting() async {
    if (_creating || _pickingReferences) return;
    final sb = ref.read(supabaseProvider);

    final title = _titleC.text.trim();
    final desc = _descC.text.trim();
    final rights = _rightsC.text.trim();
    final fee = _feeC.text.trim();

    // Минимальная валидация без лишнего UI: не создаём пустое
    if (title.isEmpty) return;

    setState(() => _creating = true);

    try {
      final dates = _selectedDates.toList()..sort((a, b) => a.compareTo(b));
      final userId = sb.auth.currentUser?.id.trim() ?? '';
      final referenceMedia = await uploadCastingReferenceMedia(
        supabase: sb,
        ownerId: userId,
        items: _pendingReferences,
      );

      // ВАЖНО: тут предполагается таблица "castings".
      // Поля можно подстроить под твою схему.
      final payload = {
        'title': title,
        'description': desc,
        'rights': rights,
        'fee': fee,
        'project_stage': castingProjectStageToString(_stage),
        'reference_media': referenceMedia.map((item) => item.toJson()).toList(),
        // храню как список ISO-дат (YYYY-MM-DD)
        'dates': dates.map((d) => _dateOnly(d).toIso8601String()).toList(),
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        await sb.from('castings').insert(payload);
      } on PostgrestException catch (e) {
        if (!SupabaseCompat.isMissingAnyColumn(e, [
          'project_stage',
          'reference_media',
        ])) {
          rethrow;
        }
        final legacyPayload = Map<String, dynamic>.from(payload)
          ..remove('project_stage')
          ..remove('reference_media');
        await sb.from('castings').insert(legacyPayload);
      }
      await AdminActionLogService(sb).log(
        actionType: 'casting_created',
        title: 'Кастинг создан',
        description: desc,
        targetTable: 'castings',
        targetText: title,
        status: 'created',
      );
      ref
        ..invalidate(castingsProvider)
        ..invalidate(myCastingResponseStatusesProvider)
        ..invalidate(actionableCastingsCountProvider)
        ..invalidate(adminSelectionListProvider)
        ..invalidate(adminSelectionCountProvider);

      if (!mounted) return;
      context.go(_returnRoute(context));
    } catch (e) {
      if (!mounted) return;
      final isRu = Localizations.localeOf(context).languageCode == 'ru';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu ? 'Не удалось создать кастинг.' : 'Could not create casting.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _pickReferences() async {
    if (_creating || _pickingReferences) return;
    setState(() => _pickingReferences = true);
    try {
      final picked = await pickCastingReferenceMedia();
      if (!mounted || picked.isEmpty) return;
      setState(() => _pendingReferences.addAll(picked));
    } finally {
      if (mounted) setState(() => _pickingReferences = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // The publish button follows the title: it is the only required field.
    _titleC.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _createCastingDesktopBreakpoint;
    if (isDesktop || kIsWeb) return _buildV2(context, t, isDesktop: isDesktop);
    return _buildLegacy(context, t);
  }

  /// v2 (web): on wide screens a two-column editor — the texts on the left,
  /// a «publish» panel (dates, stage, buttons) on the right; narrower
  /// screens stack the same blocks in one column.
  Widget _buildV2(
    BuildContext context,
    AppLocalizations t, {
    required bool isDesktop,
  }) {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final backLabel = from == 'admin' ? t.adminTab : t.castingsTab;
    final canPublish =
        !_creating && !_pickingReferences && _titleC.text.trim().isNotEmpty;
    final width = MediaQuery.sizeOf(context).width;
    final twoColumns = width >= _createCastingTwoColumnBreakpoint;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(_returnRoute(context)),
            style: TextButton.styleFrom(
              foregroundColor: Tokens.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(backLabel),
          ),
        ),
        const SizedBox(height: 12),
        Text(t.newCastingTitle, style: AppText.display.copyWith(fontSize: 36)),
        const SizedBox(height: 8),
        Text(
          t.newCastingHint,
          style: AppText.body.copyWith(color: Tokens.textSecondary),
        ),
      ],
    );

    final rightsField = _FormField(
      label: t.rights,
      child: _TextField(
        controller: _rightsC,
        hint: t.castingRightsHint,
        minLines: 2,
        maxLines: 5,
        flat: true,
      ),
    );
    final feeField = _FormField(
      label: t.fee,
      child: _TextField(controller: _feeC, hint: t.castingFeeHint, flat: true),
    );

    final mainFields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormField(
          label: t.castingTitle,
          child: _TextField(
            controller: _titleC,
            hint: t.castingTitleHint,
            flat: true,
          ),
        ),
        const SizedBox(height: 28),
        _FormField(
          label: t.projectDescription,
          child: _TextField(
            controller: _descC,
            hint: t.castingDescriptionHint,
            minLines: 5,
            maxLines: 12,
            flat: true,
          ),
        ),
        const SizedBox(height: 24),
        if (twoColumns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: rightsField),
              const SizedBox(width: 24),
              Expanded(child: feeField),
            ],
          )
        else ...[
          rightsField,
          const SizedBox(height: 24),
          feeField,
        ],
        const SizedBox(height: 28),
        _FormField(
          label: t.castingReferencesLabel,
          child: _ReferencesPicker(
            items: _pendingReferences,
            picking: _pickingReferences,
            flat: true,
            onPick: _pickReferences,
            onRemove: (index) {
              setState(() => _pendingReferences.removeAt(index));
            },
          ),
        ),
      ],
    );

    final calendar = _MultiMonthCalendar(
      initialSelected: _selectedDates,
      flat: true,
      onToggle: _toggleDate,
    );
    final stage = _StageSelector(
      value: _stage,
      flat: true,
      onChanged: (stage) => setState(() => _stage = stage),
    );
    final publishButton = FilledButton(
      onPressed: canPublish ? _createCasting : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: AppText.button.copyWith(fontSize: 15),
      ),
      child: _creating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(t.publish),
    );
    final cancelButton = OutlinedButton(
      onPressed: _creating ? null : () => context.go(_returnRoute(context)),
      child: Text(t.cancel),
    );

    // Publish panel: dates, stage and the two buttons in one bordered block.
    final sidePanel = Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: Tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FormField(label: t.dates, hint: t.castingDatesHint, child: calendar),
          const SizedBox(height: 24),
          _FormField(label: t.castingProjectStageLabel, child: stage),
          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 1, color: Tokens.border),
          const SizedBox(height: 20),
          publishButton,
          const SizedBox(height: 10),
          cancelButton,
        ],
      ),
    );

    final Widget body;
    if (twoColumns) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!kIsWeb) ...[header, const SizedBox(height: 32)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: mainFields),
              const SizedBox(width: 48),
              SizedBox(width: _createCastingSideWidth, child: sidePanel),
            ],
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!kIsWeb) ...[header, const SizedBox(height: 32)],
          mainFields,
          const SizedBox(height: 28),
          sidePanel,
        ],
      );
    }

    if (kIsWeb) {
      // Admin shell: side menu + title; the form keeps its own widths.
      return AdminShellV2(
        title: t.newCastingTitle,
        subtitle: t.newCastingHint,
        onBack: () => context.go(_returnRoute(context)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 48),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: twoColumns
                    ? _createCastingMaxWidth
                    : _createCastingFormWidth,
              ),
              child: body,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: isDesktop
              ? const EdgeInsets.fromLTRB(32, 20, 32, 48)
              : const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: twoColumns
                    ? _createCastingMaxWidth
                    : _createCastingFormWidth,
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  void _toggleDate(DateTime d) {
    setState(() {
      final dd = _dateOnly(d);
      if (_selectedDates.contains(dd)) {
        _selectedDates.remove(dd);
      } else {
        _selectedDates.add(dd);
      }
    });
  }

  /// Native apps: the pill-style form (unchanged).
  Widget _buildLegacy(BuildContext context, AppLocalizations t) {
    return Scaffold(
      backgroundColor: BrandTheme.greyMid,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              BrandAdminHeader(
                title: t.adminCreateCastingUpper,
                onBack: () => context.go(_returnRoute(context)),
                sideWidth: 172,
                trailing: TextButton(
                  onPressed: _creating ? null : _createCasting,
                  style: TextButton.styleFrom(
                    foregroundColor: BrandTheme.redTop,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: _creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Localizations.localeOf(context).languageCode == 'ru'
                                ? 'ОПУБЛИКОВАТЬ'
                                : 'PUBLISH',
                            maxLines: 1,
                            style: BrandTheme.pillText.copyWith(
                              color: BrandTheme.redTop,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _CardPill(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionTitle(t.castingTitle),
                        _TextField(controller: _titleC),
                        const SizedBox(height: 12),

                        _SectionTitle(t.projectDescription),
                        _TextField(controller: _descC, maxLines: 4),
                        const SizedBox(height: 12),

                        _SectionTitle(t.rights),
                        _TextField(controller: _rightsC, maxLines: 3),
                        const SizedBox(height: 12),

                        _SectionTitle(t.fee),
                        _TextField(controller: _feeC),
                        const SizedBox(height: 12),

                        _SectionTitle(
                          Localizations.localeOf(context).languageCode == 'ru'
                              ? 'РЕФЕРЕНСЫ'
                              : 'REFERENCES',
                        ),
                        _ReferencesPicker(
                          items: _pendingReferences,
                          picking: _pickingReferences,
                          onPick: _pickReferences,
                          onRemove: (index) {
                            setState(() => _pendingReferences.removeAt(index));
                          },
                        ),
                        const SizedBox(height: 12),

                        _SectionTitle(t.dates),
                        _MultiMonthCalendar(
                          initialSelected: _selectedDates,
                          onToggle: (d) {
                            setState(() {
                              final dd = _dateOnly(d);
                              if (_selectedDates.contains(dd)) {
                                _selectedDates.remove(dd);
                              } else {
                                _selectedDates.add(dd);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        _SectionTitle(
                          Localizations.localeOf(context).languageCode == 'ru'
                              ? 'ЭТАП ПРОЕКТА'
                              : 'PROJECT STAGE',
                        ),
                        _StageSelector(
                          value: _stage,
                          onChanged: (stage) => setState(() => _stage = stage),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _returnRoute(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    return from == 'admin' ? Routes.admin : Routes.castings;
  }
}

/// v2 form row: sentence-case label, optional hint and the control.
class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.bodyStrong.copyWith(height: 1.3)),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: AppText.small.copyWith(color: Tokens.textSecondary),
          ),
        ],
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ReferencesPicker extends StatelessWidget {
  const _ReferencesPicker({
    required this.items,
    required this.picking,
    required this.onPick,
    required this.onRemove,
    this.flat = false,
  });

  final List<PendingCastingReferenceMedia> items;
  final bool picking;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final button = flat
        ? Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: picking ? null : onPick,
              icon: Icon(
                picking
                    ? Icons.hourglass_top_rounded
                    : Icons.attach_file_rounded,
                size: 18,
              ),
              label: Text(picking ? t.loadingDots : t.castingAddFiles),
            ),
          )
        : SizedBox(
            height: BrandTheme.pillHeight,
            child: OutlinedButton.icon(
              onPressed: picking ? null : onPick,
              style: castingDialogOutlinedButtonStyle(),
              icon: Icon(
                picking
                    ? Icons.hourglass_top_rounded
                    : Icons.attach_file_rounded,
                size: 18,
              ),
              label: Text(
                picking
                    ? (isRu ? 'ВЫБОР...' : 'PICKING...')
                    : (isRu ? 'ДОБАВИТЬ ФАЙЛЫ' : 'ADD FILES'),
                style: adminCommandStyle(size: 12, letterSpacing: 0.9),
              ),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        button,
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            _ReferenceDraftTile(
              item: items[i],
              flat: flat,
              onRemove: () => onRemove(i),
            ),
            if (i != items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _ReferenceDraftTile extends StatelessWidget {
  const _ReferenceDraftTile({
    required this.item,
    required this.onRemove,
    this.flat = false,
  });

  final PendingCastingReferenceMedia item;
  final VoidCallback onRemove;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final icon = switch (item.kind) {
      CastingReferenceMediaKind.image => Icons.image_outlined,
      CastingReferenceMediaKind.video => Icons.videocam_outlined,
      CastingReferenceMediaKind.file => Icons.insert_drive_file_outlined,
    };
    final subtitle = [
      castingReferenceMediaKindLabel(item.kind, isRu: isRu),
      formatCastingReferenceSize(item.sizeBytes),
    ].where((part) => part.trim().isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: flat
          ? BoxDecoration(
              color: Tokens.surface,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
            )
          : BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
            ),
      child: Row(
        children: [
          Icon(
            icon,
            color: flat ? Tokens.textSecondary : BrandTheme.redTop,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: flat
                      ? AppText.smallStrong
                      : adminBodyStyle(
                          size: 13,
                          color: kTextDark,
                          weight: FontWeight.w800,
                        ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: flat
                      ? AppText.caption
                      : adminBodyStyle(
                          size: 11,
                          color: kTextMuted,
                          weight: FontWeight.w700,
                        ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            color: flat ? Tokens.textSecondary : kTextMuted,
            visualDensity: VisualDensity.compact,
            tooltip: isRu ? 'Удалить' : 'Remove',
          ),
        ],
      ),
    );
  }
}

class _StageSelector extends StatelessWidget {
  const _StageSelector({
    required this.value,
    required this.onChanged,
    this.flat = false,
  });

  final CastingProjectStage value;
  final ValueChanged<CastingProjectStage> onChanged;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    if (flat) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final stage in CastingProjectStage.values)
            _StageChip(
              stage: stage,
              selected: value == stage,
              onTap: () => onChanged(stage),
            ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final stage in CastingProjectStage.values)
          ChoiceChip(
            selected: value == stage,
            label: Text(castingProjectStageLabel(context, stage).toUpperCase()),
            avatar: Icon(
              castingProjectStageIcon(stage),
              size: 17,
              color: value == stage ? Colors.white : kTextDark,
            ),
            selectedColor: castingProjectStageColor(stage),
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            labelStyle: adminCommandStyle(
              size: 11,
              letterSpacing: 0.7,
              color: value == stage ? Colors.white : kTextDark,
            ),
            onSelected: (_) => onChanged(stage),
          ),
      ],
    );
  }
}

/// v2 stage choice: flat chip, dark when selected.
class _StageChip extends StatelessWidget {
  const _StageChip({
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
      color: selected ? Tokens.ink : Tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Tokens.fast,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                castingProjectStageIcon(stage),
                size: 16,
                color: selected
                    ? Tokens.textOnDark
                    : castingProjectStageColor(stage),
              ),
              const SizedBox(width: 6),
              Text(
                castingProjectStageLabel(context, stage),
                style: AppText.smallStrong.copyWith(
                  color: selected ? Tokens.textOnDark : Tokens.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: adminCommandStyle(size: 14, letterSpacing: 1.0)),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    this.maxLines = 1,
    this.minLines,
    this.hint,
    this.flat = false,
  });

  final TextEditingController controller;
  final int maxLines;
  final int? minLines;
  final String? hint;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    if (flat) {
      // Theme inputs are already v2 (48 px, radius 10, grey border).
      return TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        style: AppText.body.copyWith(fontSize: 17),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.body.copyWith(
            fontSize: 17,
            color: Tokens.textTertiary,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
      );
    }
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: adminBodyStyle(
        size: 15,
        color: kTextDark,
        weight: FontWeight.w600,
      ),
      decoration: pillInputDecoration(
        hint: '',
        focusColor: BrandTheme.redTop,
        focusWidth: 1.2,
      ),
    );
  }
}

class _CardPill extends StatelessWidget {
  const _CardPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(14),
      decoration: adminCardDecoration(),
      child: child,
    );
  }
}

/// Календарь по образцу из catalog_page, но с мультивыбором.
class _MultiMonthCalendar extends StatefulWidget {
  const _MultiMonthCalendar({
    required this.onToggle,
    this.initialSelected = const {},
    this.flat = false,
  });

  final void Function(DateTime d) onToggle;
  final Set<DateTime> initialSelected;

  /// v2 look: plain text header, accent-filled selected days.
  final bool flat;

  @override
  State<_MultiMonthCalendar> createState() => _MultiMonthCalendarState();
}

class _MultiMonthCalendarState extends State<_MultiMonthCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = _dateOnly(DateTime.now());
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final flat = widget.flat;

    final weekdays = [
      t.weekdayMonUpper,
      t.weekdayTueUpper,
      t.weekdayWedUpper,
      t.weekdayThuUpper,
      t.weekdayFriUpper,
      t.weekdaySatUpper,
      t.weekdaySunUpper,
    ];

    final now = _dateOnly(DateTime.now());
    final first = _month;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final firstWeekday = (first.weekday + 6) % 7; // monday=0

    final cells = <Widget>[];
    for (final w in weekdays) {
      cells.add(
        Center(
          child: Text(
            w,
            style: flat
                ? AppText.label
                : adminCommandStyle(
                    size: 11,
                    letterSpacing: 0.8,
                    color: kTextMid,
                  ),
          ),
        ),
      );
    }

    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final d = _dateOnly(DateTime(first.year, first.month, day));
      final disabled = d.isBefore(now);
      final selected = widget.initialSelected.contains(d);

      cells.add(
        _DowCell(
          day: day,
          disabled: disabled,
          selected: selected,
          today: d == now,
          flat: flat,
          onTap: disabled ? null : () => widget.onToggle(d),
        ),
      );
    }

    final currentMonth = DateTime(now.year, now.month, 1);
    final canGoPrev = _month.isAfter(currentMonth);
    void prev() =>
        setState(() => _month = DateTime(_month.year, _month.month - 1, 1));
    void next() =>
        setState(() => _month = DateTime(_month.year, _month.month + 1, 1));

    final monthLabel = flat
        ? _sentenceCase(_ruMonth(_month, t))
        : _ruMonth(_month, t);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (flat)
              IconButton(
                onPressed: canGoPrev ? prev : null,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
              )
            else
              GestureDetector(
                onTap: canGoPrev ? prev : null,
                child: Opacity(
                  opacity: canGoPrev ? 1 : 0.25,
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    size: 28,
                    color: kTextDark,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                monthLabel,
                textAlign: TextAlign.center,
                style: flat
                    ? AppText.smallStrong
                    : adminCommandStyle(
                        size: 15,
                        letterSpacing: 1.0,
                        color: kTextDark,
                      ),
              ),
            ),
            if (flat)
              IconButton(
                onPressed: next,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
              )
            else
              GestureDetector(
                onTap: next,
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 28,
                  color: kTextDark,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: flat ? 4 : 8,
          crossAxisSpacing: flat ? 4 : 8,
          children: cells,
        ),
      ],
    );
  }
}

class _DowCell extends StatelessWidget {
  const _DowCell({
    required this.day,
    required this.disabled,
    required this.selected,
    this.today = false,
    this.flat = false,
    this.onTap,
  });
  final int day;
  final bool disabled;
  final bool selected;
  final bool today;
  final bool flat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (flat) {
      final fg = selected
          ? Tokens.textOnDark
          : (disabled ? Tokens.textTertiary : Tokens.text);
      return Material(
        color: selected ? Tokens.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              border: today && !selected
                  ? Border.all(color: Tokens.borderStrong)
                  : null,
            ),
            child: Text(
              '$day',
              style: AppText.small.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    final bg = selected
        ? BrandTheme.redTop
        : Colors.white.withValues(alpha: kWhiteOpacity92);
    final fg = selected ? Colors.white : (disabled ? kDisabledText : kTextDark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kCalendarDayRadius),
          border: Border.all(color: kBorderColor, width: 1),
        ),
        child: Text(
          '$day',
          style: adminCommandStyle(size: 13, color: fg, letterSpacing: 0.4),
        ),
      ),
    );
  }
}

/// «ОКТЯБРЬ 2026» → «Октябрь 2026» for the v2 calendar header.
String _sentenceCase(String text) {
  if (text.isEmpty) return text;
  final lower = text.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _ruMonth(DateTime m, AppLocalizations t) {
  final months = [
    t.monthJanuaryUpper,
    t.monthFebruaryUpper,
    t.monthMarchUpper,
    t.monthAprilUpper,
    t.monthMayUpper,
    t.monthJuneUpper,
    t.monthJulyUpper,
    t.monthAugustUpper,
    t.monthSeptemberUpper,
    t.monthOctoberUpper,
    t.monthNovemberUpper,
    t.monthDecemberUpper,
  ];
  return '${months[m.month - 1]} ${m.year}';
}
