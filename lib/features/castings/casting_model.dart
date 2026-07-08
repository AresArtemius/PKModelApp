import 'casting_project_stage.dart';
import 'casting_reference_media.dart';

class CastingModel {
  const CastingModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rights,
    required this.fee,
    required this.datesText,
    required this.projectStage,
    required this.referenceMedia,
  });

  final String id;
  final String title;
  final String description;
  final String rights;
  final String fee;
  final String datesText;
  final CastingProjectStage projectStage;
  final List<CastingReferenceMedia> referenceMedia;

  factory CastingModel.fromMap(Map<String, dynamic> map) {
    final id = (map['id'] ?? '').toString();
    final title = (map['title'] ?? '').toString();
    final description = (map['description'] ?? '').toString();
    final rights = (map['rights'] ?? '').toString();
    final fee = (map['fee'] ?? '').toString();
    final datesText = _datesToText(map['dates']);
    final projectStage = castingProjectStageFromString(
      map['project_stage']?.toString(),
    );
    final referenceMedia = _referenceMediaFromValue(map['reference_media']);

    return CastingModel(
      id: id,
      title: title,
      description: description,
      rights: rights,
      fee: fee,
      datesText: datesText,
      projectStage: projectStage,
      referenceMedia: referenceMedia,
    );
  }
}

List<CastingReferenceMedia> _referenceMediaFromValue(dynamic value) {
  if (value is! List) return const <CastingReferenceMedia>[];
  return value
      .whereType<Map>()
      .map(
        (item) =>
            CastingReferenceMedia.fromJson(Map<String, dynamic>.from(item)),
      )
      .where((item) => item.url.trim().isNotEmpty)
      .toList(growable: false);
}

String _datesToText(dynamic datesRaw) {
  if (datesRaw == null) return '';
  if (datesRaw is List) {
    final parts = <String>[];
    for (final x in datesRaw) {
      final s = x?.toString().trim() ?? '';
      if (s.isNotEmpty) parts.add(s.length >= 10 ? s.substring(0, 10) : s);
    }
    return parts.join(', ');
  }
  final s = datesRaw.toString().trim();
  if (s.isEmpty) return '';
  return s.length >= 10 ? s.substring(0, 10) : s;
}
