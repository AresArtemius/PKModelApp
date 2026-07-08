import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile/profile_media_storage.dart';

const String kCastingReferenceBucket = 'profile-media';

enum CastingReferenceMediaKind { image, video, file }

class CastingReferenceMedia {
  const CastingReferenceMedia({
    required this.kind,
    required this.url,
    required this.name,
    this.previewUrl = '',
  });

  final CastingReferenceMediaKind kind;
  final String url;
  final String name;
  final String previewUrl;

  Map<String, dynamic> toJson() => {
    'kind': castingReferenceMediaKindToString(kind),
    'url': url,
    'name': name,
    if (previewUrl.trim().isNotEmpty) 'preview_url': previewUrl,
  };

  factory CastingReferenceMedia.fromJson(Map<String, dynamic> map) {
    return CastingReferenceMedia(
      kind: castingReferenceMediaKindFromString(map['kind']?.toString()),
      url: (map['url'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      previewUrl: (map['preview_url'] ?? '').toString().trim(),
    );
  }
}

class PendingCastingReferenceMedia {
  const PendingCastingReferenceMedia({
    required this.kind,
    required this.name,
    required this.bytes,
    required this.contentType,
    required this.extension,
  });

  final CastingReferenceMediaKind kind;
  final String name;
  final Uint8List bytes;
  final String contentType;
  final String extension;

  int get sizeBytes => bytes.length;
}

CastingReferenceMediaKind castingReferenceMediaKindFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'image':
      return CastingReferenceMediaKind.image;
    case 'video':
      return CastingReferenceMediaKind.video;
    case 'file':
    default:
      return CastingReferenceMediaKind.file;
  }
}

String castingReferenceMediaKindToString(CastingReferenceMediaKind kind) {
  switch (kind) {
    case CastingReferenceMediaKind.image:
      return 'image';
    case CastingReferenceMediaKind.video:
      return 'video';
    case CastingReferenceMediaKind.file:
      return 'file';
  }
}

String castingReferenceMediaKindLabel(
  CastingReferenceMediaKind kind, {
  required bool isRu,
}) {
  switch (kind) {
    case CastingReferenceMediaKind.image:
      return isRu ? 'Фото' : 'Photo';
    case CastingReferenceMediaKind.video:
      return isRu ? 'Видео' : 'Video';
    case CastingReferenceMediaKind.file:
      return isRu ? 'Файл' : 'File';
  }
}

Future<List<PendingCastingReferenceMedia>> pickCastingReferenceMedia() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: true,
  );
  final files = result?.files ?? const <PlatformFile>[];
  final items = <PendingCastingReferenceMedia>[];

  for (final file in files) {
    var bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await XFile(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) continue;

    final extension = (file.extension ?? _extensionFromName(file.name))
        .trim()
        .toLowerCase();
    final contentType = _contentTypeForExtension(extension);
    items.add(
      PendingCastingReferenceMedia(
        kind: _kindForContentType(contentType),
        name: file.name.trim().isEmpty ? 'reference.$extension' : file.name,
        bytes: bytes,
        contentType: contentType,
        extension: extension,
      ),
    );
  }

  return items;
}

Future<List<CastingReferenceMedia>> uploadCastingReferenceMedia({
  required SupabaseClient supabase,
  required String ownerId,
  required Iterable<PendingCastingReferenceMedia> items,
}) async {
  final cleanOwnerId = ownerId.trim();
  if (cleanOwnerId.isEmpty) return const <CastingReferenceMedia>[];
  final storage = ProfileMediaStorage(supabase);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final uploaded = <CastingReferenceMedia>[];
  var index = 0;

  for (final item in items) {
    final ext = item.extension.trim().isEmpty ? 'bin' : item.extension.trim();
    final path = '$cleanOwnerId/casting_references/${stamp}_${index++}.$ext';
    final url = await storage.uploadBinary(
      bucket: kCastingReferenceBucket,
      path: path,
      bytes: item.bytes,
      contentType: item.contentType,
    );
    uploaded.add(
      CastingReferenceMedia(kind: item.kind, url: url, name: item.name),
    );
  }

  return uploaded;
}

String formatCastingReferenceSize(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit += 1;
  }
  return unit == 0
      ? '${size.toStringAsFixed(0)} ${units[unit]}'
      : '${size.toStringAsFixed(1)} ${units[unit]}';
}

String _extensionFromName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return 'bin';
  return name.substring(dot + 1);
}

String _contentTypeForExtension(String extension) {
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    default:
      return 'application/octet-stream';
  }
}

CastingReferenceMediaKind _kindForContentType(String contentType) {
  if (contentType.startsWith('image/')) {
    return CastingReferenceMediaKind.image;
  }
  if (contentType.startsWith('video/')) {
    return CastingReferenceMediaKind.video;
  }
  return CastingReferenceMediaKind.file;
}
