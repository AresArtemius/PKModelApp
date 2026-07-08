import 'package:flutter/material.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../../gen_l10n/app_localizations.dart';

import 'casting_model.dart';
import 'casting_project_stage.dart';
import 'casting_response_status.dart';

class CastingCard extends StatelessWidget {
  const CastingCard({
    super.key,
    required this.casting,
    required this.isResponding,
    this.responseStatus,
    this.isDisabled = false,
    required this.onRespondTap,
    this.onDeleteTap,
  });

  final CastingModel casting;
  final bool isResponding;
  final CastingResponseStatus? responseStatus;
  final bool isDisabled;
  final void Function(String castingId) onRespondTap;
  final void Function(String castingId)? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final canTap = !isResponding && !isDisabled;
    final dates = casting.datesText;
    final status = responseStatus;

    return Container(
      padding: kCastingCardPad,
      decoration: castingCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  casting.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: kCastingTitleStyle,
                ),
              ),
              const SizedBox(width: 12),
              if (onDeleteTap != null) ...[
                SizedBox(
                  width: 42,
                  height: kCastingRespondButtonH,
                  child: IconButton(
                    tooltip: t.deleteUpper,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: BrandTheme.redTop,
                    onPressed: () => onDeleteTap!(casting.id),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              SizedBox(
                width: 176,
                child: _CastingActionButton(
                  label: isResponding
                      ? t.loadingDots
                      : (status == null
                            ? t.respondUpper
                            : _castingActionLocaleText(
                                context,
                                'ДОБАВИТЬ',
                                'ADD MORE',
                              )),
                  onTap: canTap ? () => onRespondTap(casting.id) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CastingStagePill(stage: casting.projectStage),
          if (casting.referenceMedia.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CastingReferenceCountPill(count: casting.referenceMedia.length),
          ],
          if (casting.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(casting.description, style: kCastingBodyStyle),
          ],
          if (casting.rights.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(casting.rights, style: kCastingBodyStyle),
          ],
          if (casting.fee.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(casting.fee, style: kCastingBodyStyle),
          ],
          if (dates.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(dates, style: kCastingBodyStyle),
          ],
        ],
      ),
    );
  }
}

String _castingActionLocaleText(BuildContext context, String ru, String en) {
  return Localizations.localeOf(context).languageCode == 'ru' ? ru : en;
}

class _CastingReferenceCountPill extends StatelessWidget {
  const _CastingReferenceCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file_rounded, size: 15, color: kTextDark),
          const SizedBox(width: 6),
          Text(
            isRu ? 'РЕФЕРЕНСЫ: $count' : 'REFERENCES: $count',
            style: BrandTheme.pillText.copyWith(
              color: kTextDark,
              fontSize: 11,
              letterSpacing: 0.75,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CastingStagePill extends StatelessWidget {
  const _CastingStagePill({required this.stage});

  final CastingProjectStage stage;

  @override
  Widget build(BuildContext context) {
    final color = castingProjectStageColor(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(castingProjectStageIcon(stage), size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            castingProjectStageLabel(context, stage).toUpperCase(),
            style: BrandTheme.pillText.copyWith(
              color: color,
              fontSize: 11,
              letterSpacing: 0.75,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CastingActionButton extends StatelessWidget {
  const _CastingActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.60,
        child: Container(
          height: kCastingRespondButtonH,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandTheme.pillRadius),
            gradient: BrandTheme.darkPillGradient,
            boxShadow: BrandTheme.basePillShadow(isDark: true),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: BrandTheme.pillText.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 14,
                letterSpacing: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
