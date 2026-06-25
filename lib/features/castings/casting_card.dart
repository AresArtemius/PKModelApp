import 'package:flutter/material.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';
import '../../gen_l10n/app_localizations.dart';

import 'casting_model.dart';
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
    final hasResponded = responseStatus != null;
    final canTap = !hasResponded && !isResponding && !isDisabled;
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
                            : castingResponseStatusLabel(t, status)),
                  onTap: canTap ? () => onRespondTap(casting.id) : null,
                ),
              ),
            ],
          ),
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
