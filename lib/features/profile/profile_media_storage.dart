import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ProfileMediaUploadResult {
  const ProfileMediaUploadResult({
    required this.photoUrls,
    required this.videoUrls,
    required this.videoPreviewUrls,
  });

  final List<String> photoUrls;
  final List<String> videoUrls;
  final List<String> videoPreviewUrls;
}

class ProfileMediaStorage {
  const ProfileMediaStorage(this._sb);

  static const _maxPhotoSide = 2048;
  static const _photoJpegQuality = 86;

  final SupabaseClient _sb;

  String _ext(XFile file) {
    final source = file.name.trim().isNotEmpty ? file.name : file.path;
    final p = source.toLowerCase();
    final i = p.lastIndexOf('.');
    if (i == -1) return '';
    return p.substring(i + 1);
  }

  String _contentType({
    required bool isVideo,
    required String ext,
    String? mimeType,
  }) {
    final mime = mimeType?.trim().toLowerCase() ?? '';
    if (mime.startsWith('image/') || mime.startsWith('video/')) return mime;

    if (isVideo) {
      if (ext == 'mov') return 'video/quicktime';
      if (ext == 'webm') return 'video/webm';
      return 'video/mp4';
    }
    if (ext == 'webp') return 'image/webp';
    if (ext == 'png') return 'image/png';
    return 'image/jpeg';
  }

  Future<String> uploadBinary({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _sb.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return _sb.storage.from(bucket).getPublicUrl(path);
  }

  Future<ProfileMediaUploadResult> uploadPickedMedia({
    required String bucket,
    required String uid,
    required List<XFile> pickedPhotos,
    required List<XFile> pickedVideos,
  }) async {
    if (pickedPhotos.isEmpty && pickedVideos.isEmpty) {
      return const ProfileMediaUploadResult(
        photoUrls: <String>[],
        videoUrls: <String>[],
        videoPreviewUrls: <String>[],
      );
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;

    Future<String> uploadPhoto(int i, XFile xf) async {
      return this.uploadPhoto(
        bucket: bucket,
        uid: uid,
        file: xf,
        pathSeed: '${stamp}_$i',
      );
    }

    Future<({String videoUrl, String previewUrl})> uploadVideo(
      int i,
      XFile xf,
    ) async {
      return this.uploadVideo(
        bucket: bucket,
        uid: uid,
        file: xf,
        pathSeed: '${stamp}_$i',
      );
    }

    final uploadedPhotos = await Future.wait([
      for (int i = 0; i < pickedPhotos.length; i++)
        uploadPhoto(i, pickedPhotos[i]),
    ]);
    final uploadedVideoItems = await Future.wait([
      for (int i = 0; i < pickedVideos.length; i++)
        uploadVideo(i, pickedVideos[i]),
    ]);

    return ProfileMediaUploadResult(
      photoUrls: List<String>.from(uploadedPhotos),
      videoUrls: uploadedVideoItems.map((e) => e.videoUrl).toList(),
      videoPreviewUrls: uploadedVideoItems.map((e) => e.previewUrl).toList(),
    );
  }

  Future<String> uploadPhoto({
    required String bucket,
    required String uid,
    required XFile file,
    required String pathSeed,
  }) async {
    final ext = _ext(file);
    final ct = _contentType(isVideo: false, ext: ext, mimeType: file.mimeType);
    final originalBytes = await file.readAsBytes();
    final prepared = _preparePhotoBytes(
      originalBytes,
      originalExtension: ext,
      originalContentType: ct,
    );
    final name = '$pathSeed.${prepared.extension}';
    final storagePath = '$uid/photos/$name';

    return uploadBinary(
      bucket: bucket,
      path: storagePath,
      bytes: prepared.bytes,
      contentType: prepared.contentType,
    );
  }

  ({Uint8List bytes, String extension, String contentType}) _preparePhotoBytes(
    Uint8List originalBytes, {
    required String originalExtension,
    required String originalContentType,
  }) {
    final fallbackExtension = originalExtension.trim().isEmpty
        ? 'jpg'
        : originalExtension.trim().toLowerCase();

    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      return (
        bytes: originalBytes,
        extension: fallbackExtension,
        contentType: originalContentType,
      );
    }

    var output = img.bakeOrientation(decoded);
    if (output.width > _maxPhotoSide || output.height > _maxPhotoSide) {
      output = output.width >= output.height
          ? img.copyResize(
              output,
              width: _maxPhotoSide,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              output,
              height: _maxPhotoSide,
              interpolation: img.Interpolation.average,
            );
    }

    final encoded = Uint8List.fromList(
      img.encodeJpg(output, quality: _photoJpegQuality),
    );
    if (encoded.isEmpty) {
      return (
        bytes: originalBytes,
        extension: fallbackExtension,
        contentType: originalContentType,
      );
    }

    final originalFits =
        decoded.width <= _maxPhotoSide && decoded.height <= _maxPhotoSide;
    if (originalFits && encoded.length >= originalBytes.length) {
      return (
        bytes: originalBytes,
        extension: fallbackExtension,
        contentType: originalContentType,
      );
    }

    return (bytes: encoded, extension: 'jpg', contentType: 'image/jpeg');
  }

  Future<({String videoUrl, String previewUrl})> uploadVideo({
    required String bucket,
    required String uid,
    required XFile file,
    required String pathSeed,
  }) async {
    final ext = _ext(file);
    final ct = _contentType(isVideo: true, ext: ext, mimeType: file.mimeType);
    final name = '$pathSeed.${ext.isEmpty ? 'mp4' : ext}';
    final storagePath = '$uid/videos/$name';
    final previewBytesFuture = _videoPreviewBytes(file);

    final videoBytes = await file.readAsBytes();
    final videoUrl = await uploadBinary(
      bucket: bucket,
      path: storagePath,
      bytes: videoBytes,
      contentType: ct,
    );

    var previewUrl = '';
    try {
      final previewBytes = await previewBytesFuture;
      if (previewBytes != null && previewBytes.isNotEmpty) {
        final previewPath = '$uid/video_previews/$pathSeed.jpg';
        previewUrl = await uploadBinary(
          bucket: bucket,
          path: previewPath,
          bytes: previewBytes,
          contentType: 'image/jpeg',
        );
      }
    } catch (_) {
      previewUrl = '';
    }
    return (videoUrl: videoUrl, previewUrl: previewUrl);
  }

  Future<Uint8List?> _videoPreviewBytes(XFile xf) async {
    if (kIsWeb) return null;
    final path = xf.path.trim();
    if (path.isEmpty || !File(path).existsSync()) return null;
    return VideoThumbnail.thumbnailData(
      video: path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 512,
      quality: 72,
    );
  }
}
