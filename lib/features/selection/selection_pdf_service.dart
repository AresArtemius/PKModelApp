import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/public_links.dart';
import 'selection_export_item.dart';
import 'selection_pdf_options.dart';

class SelectionPdfService {
  const SelectionPdfService();

  String buildModelUrl(String modelId) {
    final id = modelId.trim();
    if (id.isEmpty) return '';
    return publicProfileLink(id);
  }

  Future<void> previewSelectionPdf({
    required String title,
    required List<SelectionExportItem> items,
    required SelectionPdfOptions options,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) =>
          buildSelectionPdf(title: title, items: items, options: options),
      name: title.trim().isEmpty ? 'selection.pdf' : '$title.pdf',
    );
  }

  Future<Uint8List> buildSelectionPdf({
    required String title,
    required List<SelectionExportItem> items,
    required SelectionPdfOptions options,
  }) async {
    final doc = pw.Document();

    final imageBytes = <String, Uint8List?>{};
    if (options.includePhoto) {
      for (final item in items) {
        for (final url in item.photoUrls.take(3)) {
          final cleanUrl = url.trim();
          if (cleanUrl.isEmpty || imageBytes.containsKey(cleanUrl)) continue;
          imageBytes[cleanUrl] = await _loadImageBytes(cleanUrl);
        }
      }
    }

    final baseFont = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        ),
        build: (_) => [
          pw.Text(
            title.trim().isEmpty ? 'Selection' : title,
            style: pw.TextStyle(font: boldFont, fontSize: 22),
          ),
          pw.SizedBox(height: 14),
          ...items.map(
            (item) => _buildCard(
              item: item,
              options: options,
              imageData: imageBytes,
              baseFont: baseFont,
              boldFont: boldFont,
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildCard({
    required SelectionExportItem item,
    required SelectionPdfOptions options,
    required Map<String, Uint8List?> imageData,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final info = <pw.Widget>[];

    void addLine(String label, String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;

      info.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            '$label: $trimmed',
            style: pw.TextStyle(font: baseFont, fontSize: 11),
          ),
        ),
      );
    }

    void addLink(String url) {
      final trimmed = url.trim();
      if (trimmed.isEmpty) return;

      info.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
          child: pw.UrlLink(
            destination: trimmed,
            child: pw.SizedBox(
              width: 118,
              height: 30,
              child: pw.Container(
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'ОТКРЫТЬ МОДЕЛЬ',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 10,
                    color: PdfColors.blue700,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    void addInt(String label, int value, {String suffix = ''}) {
      if (value <= 0) return;
      final text = suffix.isEmpty ? '$value' : '$value $suffix';
      addLine(label, text);
    }

    if (options.includeFullName) {
      addLine('ФИО', item.fullName);
    }
    if (options.includeAge) {
      addInt('Возраст', item.age);
    }
    if (options.includeHeight) {
      addInt('Рост', item.height, suffix: 'см');
    }
    if (options.includeCity) {
      addLine('Город', item.city);
    }
    if (options.includeCountry) {
      addLine('Страна', item.country);
    }
    if (options.includeEyeColor) {
      addLine('Цвет глаз', item.eyeColor);
    }
    if (options.includeHairColor) {
      addLine('Цвет волос', item.hairColor);
    }

    if (options.includeMeasurements) {
      final parts = <String>[];
      if (item.bust > 0) parts.add('B ${item.bust}');
      if (item.waist > 0) parts.add('W ${item.waist}');
      if (item.hips > 0) parts.add('H ${item.hips}');
      if (parts.isNotEmpty) {
        addLine('Параметры', parts.join(' / '));
      }
    }

    if (options.includeShoeSize) {
      addInt('Обувь', item.shoeSize);
    }
    if (options.includeHourlyRate) {
      addInt('Мин. в час', item.minHourlyRate);
    }
    if (options.includeDailyFee) {
      addInt('Мин. в день', item.minDailyFee);
    }
    addLink(buildModelUrl(item.id));

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (options.includePhoto)
            _buildPhotoStrip(
              item: item,
              imageData: imageData,
              baseFont: baseFont,
            ),
          if (options.includePhoto) pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: info.isEmpty
                  ? [
                      pw.Text(
                        item.fullName.trim().isEmpty ? '—' : item.fullName,
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                      ),
                    ]
                  : info,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPhotoStrip({
    required SelectionExportItem item,
    required Map<String, Uint8List?> imageData,
    required pw.Font baseFont,
  }) {
    final urls = item.photoUrls.take(3).toList(growable: false);
    if (urls.isEmpty) {
      return pw.Container(
        width: 110,
        height: 140,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text(
            'NO PHOTO',
            style: pw.TextStyle(font: baseFont, fontSize: 10),
          ),
        ),
      );
    }

    final tileWidth = urls.length == 1 ? 110.0 : 74.0;
    return pw.Row(
      children: [
        for (var i = 0; i < urls.length; i++) ...[
          pw.Container(
            width: tileWidth,
            height: 140,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: imageData[urls[i].trim()] != null
                ? pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(
                      pw.MemoryImage(imageData[urls[i].trim()]!),
                      fit: pw.BoxFit.cover,
                    ),
                  )
                : pw.Center(
                    child: pw.Text(
                      'NO PHOTO',
                      style: pw.TextStyle(font: baseFont, fontSize: 9),
                    ),
                  ),
          ),
          if (i != urls.length - 1) pw.SizedBox(width: 6),
        ],
      ],
    );
  }

  Future<Uint8List?> _loadImageBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
