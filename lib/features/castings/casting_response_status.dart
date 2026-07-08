import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';

enum CastingResponseStatus {
  submitted,
  shortlist,
  callback,
  approved,
  reserve,
  viewed,
  invited,
  rejected,
}

CastingResponseStatus castingResponseStatusFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'shortlist':
      return CastingResponseStatus.shortlist;
    case 'callback':
      return CastingResponseStatus.callback;
    case 'approved':
      return CastingResponseStatus.approved;
    case 'reserve':
      return CastingResponseStatus.reserve;
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
    case CastingResponseStatus.shortlist:
      return 'shortlist';
    case CastingResponseStatus.callback:
      return 'callback';
    case CastingResponseStatus.approved:
      return 'approved';
    case CastingResponseStatus.reserve:
      return 'reserve';
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
    case CastingResponseStatus.shortlist:
      return t.localeName == 'ru' ? 'Шортлист' : 'Shortlist';
    case CastingResponseStatus.callback:
      return t.localeName == 'ru' ? 'Коллбек' : 'Callback';
    case CastingResponseStatus.approved:
      return t.localeName == 'ru' ? 'Утвержденные' : 'Approved';
    case CastingResponseStatus.reserve:
      return t.localeName == 'ru' ? 'Резерв' : 'Reserve';
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
    case CastingResponseStatus.shortlist:
      return const Color(0xFF5C5C5C);
    case CastingResponseStatus.callback:
      return const Color(0xFFB00000);
    case CastingResponseStatus.approved:
      return const Color(0xFF1B7F3A);
    case CastingResponseStatus.reserve:
      return const Color(0xFF9A6A00);
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
  if (list.contains(CastingResponseStatus.approved)) {
    return CastingResponseStatus.approved;
  }
  if (list.contains(CastingResponseStatus.callback)) {
    return CastingResponseStatus.callback;
  }
  if (list.contains(CastingResponseStatus.invited)) {
    return CastingResponseStatus.invited;
  }
  if (list.contains(CastingResponseStatus.reserve)) {
    return CastingResponseStatus.reserve;
  }
  if (list.contains(CastingResponseStatus.shortlist)) {
    return CastingResponseStatus.shortlist;
  }
  if (list.contains(CastingResponseStatus.viewed)) {
    return CastingResponseStatus.viewed;
  }
  if (list.contains(CastingResponseStatus.submitted)) {
    return CastingResponseStatus.submitted;
  }
  return CastingResponseStatus.rejected;
}
