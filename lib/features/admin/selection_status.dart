import 'package:flutter/material.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../ui/brand/brand_theme.dart';
import '../../ui/brand/ui_constants.dart';

enum SelectionStatus {
  draft('draft'),
  sentToClient('sent_to_client'),
  clientViewed('client_viewed'),
  selected('selected'),
  rejected('rejected');

  const SelectionStatus(this.storageValue);

  final String storageValue;
}

SelectionStatus selectionStatusFromString(Object? value) {
  final raw = value?.toString().trim().toLowerCase();
  return switch (raw) {
    'sent_to_client' || 'sent' => SelectionStatus.sentToClient,
    'client_viewed' || 'viewed' => SelectionStatus.clientViewed,
    'selected' || 'chosen' => SelectionStatus.selected,
    'rejected' || 'declined' => SelectionStatus.rejected,
    _ => SelectionStatus.draft,
  };
}

String selectionStatusLabel(AppLocalizations t, SelectionStatus status) {
  return switch (status) {
    SelectionStatus.draft => t.selectionStatusDraft,
    SelectionStatus.sentToClient => t.selectionStatusSent,
    SelectionStatus.clientViewed => t.selectionStatusViewed,
    SelectionStatus.selected => t.selectionStatusSelected,
    SelectionStatus.rejected => t.selectionStatusRejected,
  };
}

Color selectionStatusColor(SelectionStatus status) {
  return switch (status) {
    SelectionStatus.draft => kTextMuted,
    SelectionStatus.sentToClient => kTextDark,
    SelectionStatus.clientViewed => BrandTheme.redTop,
    SelectionStatus.selected => const Color(0xFF177245),
    SelectionStatus.rejected => const Color(0xFF9E1B1B),
  };
}
