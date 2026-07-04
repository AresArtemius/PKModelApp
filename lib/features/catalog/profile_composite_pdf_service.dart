import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/public_links.dart';
import '../../gen_l10n/app_localizations.dart';
import '../profile/profile_model.dart';
import 'model_data.dart';

class ProfileCompositePdfService {
  const ProfileCompositePdfService();

  Future<void> previewComposite({
    required AppLocalizations t,
    required ModelVm model,
  }) async {
    final fileName = _safeFileName(model.fullName);
    await Printing.layoutPdf(
      name: fileName.isEmpty ? 'composite.pdf' : '$fileName-composite.pdf',
      onLayout: (_) => buildComposite(t: t, model: model),
    );
  }

  Future<Uint8List> buildComposite({
    required AppLocalizations t,
    required ModelVm model,
  }) async {
    final doc = pw.Document();
    final baseFont = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();
    final photos = model.displayPhotoUrls.take(5).toList(growable: false);
    final photoBytes = <String, Uint8List?>{};
    for (final url in photos) {
      photoBytes[url] = await _loadImageBytes(url);
    }

    final title = model.fullName.trim().isEmpty
        ? t.profileNoName
        : model.fullName.trim();
    final roles = _profileRolesLabel(t, model.effectiveProfileRoles);
    final location = [
      model.city.trim(),
      model.country.trim(),
    ].where((v) => v.isNotEmpty).join(', ');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(title: title, roles: roles, boldFont: boldFont),
            pw.SizedBox(height: 14),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: _photoBox(
                      bytes: photos.isNotEmpty
                          ? photoBytes[photos.first]
                          : null,
                      placeholder: 'PK',
                      radius: 12,
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _infoPanel(
                          t: t,
                          model: model,
                          location: location,
                          baseFont: baseFont,
                          boldFont: boldFont,
                        ),
                        pw.SizedBox(height: 12),
                        pw.Expanded(
                          child: _photoGrid(
                            photos: photos.skip(1).toList(growable: false),
                            photoBytes: photoBytes,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            _footer(model: model, baseFont: baseFont, boldFont: boldFont),
          ],
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _header({
    required String title,
    required String roles,
    required pw.Font boldFont,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Container(
          width: 48,
          height: 48,
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFB60000),
            shape: pw.BoxShape.circle,
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'PK',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 18,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                maxLines: 1,
                style: pw.TextStyle(font: boldFont, fontSize: 26),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                roles.toUpperCase(),
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  letterSpacing: 2,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        pw.Text(
          'COMPOSITE',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 10,
            letterSpacing: 2.6,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _infoPanel({
    required AppLocalizations t,
    required ModelVm model,
    required String location,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final rows = <({String label, String value})>[
      if (model.usesPhysicalBasics && model.age > 0)
        (label: t.profileAge, value: '${model.age}'),
      if (model.usesPhysicalBasics && model.height > 0)
        (label: t.profileHeightCm, value: '${model.height} ${t.cm}'),
      if (model.usesModelMeasurements &&
          (model.bust > 0 || model.waist > 0 || model.hips > 0))
        (
          label: _localized(t, 'Параметры', 'Measurements'),
          value: [
            if (model.bust > 0) '${model.bust}',
            if (model.waist > 0) '${model.waist}',
            if (model.hips > 0) '${model.hips}',
          ].join(' / '),
        ),
      if ((model.shoeSize ?? 0) > 0)
        (label: t.profileShoeSize, value: '${model.shoeSize}'),
      if (model.eyeColor.trim().isNotEmpty)
        (label: t.profileEyeColor, value: model.eyeColor.trim()),
      if (model.hairColor.trim().isNotEmpty)
        (label: t.profileHairColor, value: model.hairColor.trim()),
      if (location.isNotEmpty) (label: t.profileCity, value: location),
      if ((model.minHourlyRate ?? 0) > 0)
        (label: t.profileMinHourlyRate, value: '${model.minHourlyRate}'),
      if ((model.minDailyFee ?? 0) > 0)
        (label: t.profileMinDailyFee, value: '${model.minDailyFee}'),
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            t.profileDetailsUpper,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 11,
              letterSpacing: 1.8,
            ),
          ),
          pw.SizedBox(height: 10),
          for (final row in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      row.label,
                      style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(
                      row.value,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: boldFont, fontSize: 9.5),
                    ),
                  ),
                ],
              ),
            ),
          if (model.resume.trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              t.profileResumeUpper,
              style: pw.TextStyle(font: boldFont, fontSize: 10),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              model.resume.trim(),
              maxLines: 8,
              style: pw.TextStyle(
                font: baseFont,
                fontSize: 9,
                height: 1.25,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _photoGrid({
    required List<String> photos,
    required Map<String, Uint8List?> photoBytes,
  }) {
    if (photos.isEmpty) {
      return _photoBox(bytes: null, placeholder: 'NO PHOTO', radius: 12);
    }

    final boxes = [
      for (final url in photos.take(4))
        _photoBox(bytes: photoBytes[url], placeholder: 'PHOTO', radius: 10),
    ];
    while (boxes.length < 4) {
      boxes.add(_photoBox(bytes: null, placeholder: 'PHOTO', radius: 10));
    }

    return pw.Column(
      children: [
        pw.Expanded(
          child: pw.Row(
            children: [
              pw.Expanded(child: boxes[0]),
              pw.SizedBox(width: 8),
              pw.Expanded(child: boxes[1]),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Expanded(
          child: pw.Row(
            children: [
              pw.Expanded(child: boxes[2]),
              pw.SizedBox(width: 8),
              pw.Expanded(child: boxes[3]),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _photoBox({
    required Uint8List? bytes,
    required String placeholder,
    required double radius,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(radius),
      ),
      child: bytes != null
          ? pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover)
          : pw.Center(
              child: pw.Text(
                placeholder,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                  letterSpacing: 1.4,
                ),
              ),
            ),
    );
  }

  pw.Widget _footer({
    required ModelVm model,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final link = publicProfileLink(model.id);
    return pw.Row(
      children: [
        pw.Text(
          'PK MANAGEMENT',
          style: pw.TextStyle(font: boldFont, fontSize: 10, letterSpacing: 2),
        ),
        pw.Spacer(),
        pw.UrlLink(
          destination: link,
          child: pw.Text(
            link,
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 9,
              color: PdfColors.blue700,
            ),
          ),
        ),
      ],
    );
  }

  Future<Uint8List?> _loadImageBytes(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(cleanUrl));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _localized(AppLocalizations t, String ru, String en) {
    return t.localeName.toLowerCase().startsWith('ru') ? ru : en;
  }

  String _profileRolesLabel(
    AppLocalizations t,
    Iterable<ProfessionalProfileType> roles,
  ) {
    return normalizeProfileRoles(roles)
        .map((role) {
          return switch (role) {
            ProfessionalProfileType.model => t.profileTypeModel,
            ProfessionalProfileType.actor => t.profileTypeActor,
            ProfessionalProfileType.photographer => t.profileTypePhotographer,
            ProfessionalProfileType.videographer => t.profileTypeVideographer,
            ProfessionalProfileType.stylist => t.profileTypeStylist,
            ProfessionalProfileType.makeupArtist => t.profileTypeMakeupArtist,
            ProfessionalProfileType.hairStylist => t.profileTypeHairStylist,
          };
        })
        .join(' • ');
  }

  String _safeFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Zа-яА-Я0-9_-]+'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
