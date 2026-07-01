import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
    ValueChanged<double>? onProgress,
  }) async {
    if (onProgress != null) {
      await _uploadBinaryWithProgress(
        bucket: bucket,
        path: path,
        bytes: bytes,
        contentType: contentType,
        onProgress: onProgress,
      );
      return _sb.storage.from(bucket).getPublicUrl(path);
    }

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
    ValueChanged<double>? onProgress,
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
      onProgress: onProgress,
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
    ValueChanged<double>? onProgress,
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
      onProgress: onProgress,
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

  Future<void> _uploadBinaryWithProgress({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
    required ValueChanged<double> onProgress,
  }) async {
    final storage = _sb.storage.from(bucket);
    final encodedPath = Uri.encodeFull(path);
    final uri = Uri.parse('${storage.url}/object/$bucket/$encodedPath');
    final multipartRequest = http.MultipartRequest('POST', uri)
      ..headers.addAll(storage.headers)
      ..headers['x-upsert'] = 'false'
      ..fields['cacheControl'] = '3600'
      ..files.add(
        http.MultipartFile.fromBytes(
          '',
          bytes,
          filename: '',
          contentType: MediaType.parse(contentType),
        ),
      );

    final total = multipartRequest.contentLength;
    final bodyStream = multipartRequest.finalize();
    final request = http.StreamedRequest('POST', uri)
      ..headers.addAll(multipartRequest.headers)
      ..contentLength = total;

    onProgress(0);
    final responseFuture = request.send();
    var sent = 0;
    await for (final chunk in bodyStream) {
      sent += chunk.length;
      request.sink.add(chunk);
      if (total > 0) {
        onProgress((sent / total).clamp(0.0, 1.0));
      }
    }
    await request.sink.close();

    final response = await http.Response.fromStream(await responseFuture);
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw StorageException(
        _storageErrorMessage(response),
        statusCode: '${response.statusCode}',
      );
    }
    onProgress(1);
  }

  String _storageErrorMessage(http.Response response) {
    if (response.body.trim().isEmpty) {
      return response.reasonPhrase ?? 'Storage upload failed';
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final message = decoded['message'] ?? decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {
      // Keep the raw body below.
    }
    return response.body;
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
