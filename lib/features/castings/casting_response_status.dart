import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';

enum CastingResponseStatus { submitted, viewed, invited, rejected }

CastingResponseStatus castingResponseStatusFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'viewed':
      return CastingResponseStatus.viewed;
    case 'invited':
      return CastingResponseStatus.invited;
    case 'rejected':
      return CastingResponseStatus.rejected;
    case 'submitted':
    default:
      return CastingResponseStatus.submitted;
  }
}

String castingResponseStatusToString(CastingResponseStatus status) {
  switch (status) {
    case CastingResponseStatus.submitted:
      return 'submitted';
    case CastingResponseStatus.viewed:
      return 'viewed';
    case CastingResponseStatus.invited:
      return 'invited';
    case CastingResponseStatus.rejected:
      return 'rejected';
  }
}

String castingResponseStatusLabel(
  AppLocalizations t,
  CastingResponseStatus status,
) {
  switch (status) {
    case CastingResponseStatus.submitted:
      return t.castingResponseStatusSubmitted;
    case CastingResponseStatus.viewed:
      return t.castingResponseStatusViewed;
    case CastingResponseStatus.invited:
      return t.castingResponseStatusInvited;
    case CastingResponseStatus.rejected:
      return t.castingResponseStatusRejected;
  }
}

Color castingResponseStatusColor(CastingResponseStatus status) {
  switch (status) {
    case CastingResponseStatus.submitted:
      return BrandTheme.textDark;
    case CastingResponseStatus.viewed:
      return const Color(0xFF6A6A6A);
    case CastingResponseStatus.invited:
      return BrandTheme.redTop;
    case CastingResponseStatus.rejected:
      return const Color(0xFF8A8A8A);
  }
}

CastingResponseStatus mergeCastingResponseStatuses(
  Iterable<CastingResponseStatus> statuses,
) {
  final list = statuses.toList(growable: false);
  if (list.contains(CastingResponseStatus.invited)) {
    return CastingResponseStatus.invited;
  }
  if (list.contains(CastingResponseStatus.viewed)) {
    return CastingResponseStatus.viewed;
  }
  if (list.contains(CastingResponseStatus.submitted)) {
    return CastingResponseStatus.submitted;
  }
  return CastingResponseStatus.rejected;
}
