import 'package:flutter/material.dart';

import '../../ui/brand/brand_theme.dart';

enum CastingProjectStage {
  intake,
  acceptingApplications,
  shortlist,
  callback,
  approval,
  shoot,
  completed,
}

const defaultCastingProjectStage = CastingProjectStage.intake;

CastingProjectStage castingProjectStageFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'accepting_applications':
      return CastingProjectStage.acceptingApplications;
    case 'shortlist':
      return CastingProjectStage.shortlist;
    case 'callback':
      return CastingProjectStage.callback;
    case 'approval':
      return CastingProjectStage.approval;
    case 'shoot':
      return CastingProjectStage.shoot;
    case 'completed':
      return CastingProjectStage.completed;
    case 'intake':
    default:
      return CastingProjectStage.intake;
  }
}

String castingProjectStageToString(CastingProjectStage stage) {
  return switch (stage) {
    CastingProjectStage.intake => 'intake',
    CastingProjectStage.acceptingApplications => 'accepting_applications',
    CastingProjectStage.shortlist => 'shortlist',
    CastingProjectStage.callback => 'callback',
    CastingProjectStage.approval => 'approval',
    CastingProjectStage.shoot => 'shoot',
    CastingProjectStage.completed => 'completed',
  };
}

String castingProjectStageLabel(
  BuildContext context,
  CastingProjectStage stage,
) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  return switch (stage) {
    CastingProjectStage.intake => ru ? 'Подготовка' : 'Intake',
    CastingProjectStage.acceptingApplications =>
      ru ? 'Прием заявок' : 'Applications',
    CastingProjectStage.shortlist => ru ? 'Шортлист' : 'Shortlist',
    CastingProjectStage.callback => ru ? 'Коллбек' : 'Callback',
    CastingProjectStage.approval => ru ? 'Утверждение' : 'Approval',
    CastingProjectStage.shoot => ru ? 'Съемка' : 'Shoot',
    CastingProjectStage.completed => ru ? 'Завершен' : 'Completed',
  };
}

IconData castingProjectStageIcon(CastingProjectStage stage) {
  return switch (stage) {
    CastingProjectStage.intake => Icons.assignment_rounded,
    CastingProjectStage.acceptingApplications => Icons.how_to_reg_rounded,
    CastingProjectStage.shortlist => Icons.playlist_add_check_rounded,
    CastingProjectStage.callback => Icons.record_voice_over_rounded,
    CastingProjectStage.approval => Icons.verified_rounded,
    CastingProjectStage.shoot => Icons.videocam_rounded,
    CastingProjectStage.completed => Icons.flag_rounded,
  };
}

Color castingProjectStageColor(CastingProjectStage stage) {
  return switch (stage) {
    CastingProjectStage.intake => const Color(0xFF4B5563),
    CastingProjectStage.acceptingApplications => BrandTheme.redTop,
    CastingProjectStage.shortlist => const Color(0xFF1F2937),
    CastingProjectStage.callback => const Color(0xFF7C3AED),
    CastingProjectStage.approval => const Color(0xFF0F766E),
    CastingProjectStage.shoot => const Color(0xFFB45309),
    CastingProjectStage.completed => const Color(0xFF4B5563),
  };
}
