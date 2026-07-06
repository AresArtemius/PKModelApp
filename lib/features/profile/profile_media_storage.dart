import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'profile_video_thumbnail_stub.dart'
    if (dart.library.html) 'profile_video_thumbnail_web.dart';

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

class ProfileMediaUploadCancelled implements Exception {
  const ProfileMediaUploadCancelled();

  @override
  String toString() => 'Загрузка остановлена';
}

class ProfileMediaUploadCancelToken {
  bool _cancelled = false;
  final Completer<void> _cancelledCompleter = Completer<void>();

  bool get isCancelled => _cancelled;

  Future<void> get cancelled => _cancelledCompleter.future;

  void cancel() {
    _cancelled = true;
    if (!_cancelledCompleter.isCompleted) {
      _cancelledCompleter.complete();
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const ProfileMediaUploadCancelled();
  }
}

class ProfileMediaResumableProgress {
  const ProfileMediaResumableProgress({
    required this.progress,
    required this.uploadUrl,
    required this.uploadedBytes,
  });

  final double progress;
  final String uploadUrl;
  final int uploadedBytes;
}

class ProfileMediaStorage {
  const ProfileMediaStorage(this._sb);

  static const _maxPhotoSide = 2048;
  static const _photoJpegQuality = 86;
  static const _tusVersion = '1.0.0';
  static const _tusChunkSize = 6 * 1024 * 1024;

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
    ProfileMediaUploadCancelToken? cancelToken,
  }) async {
    if (onProgress != null) {
      try {
        await _uploadBinaryWithProgress(
          bucket: bucket,
          path: path,
          bytes: bytes,
          contentType: contentType,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
        return _sb.storage.from(bucket).getPublicUrl(path);
      } on ProfileMediaUploadCancelled {
        rethrow;
      } catch (_) {
        cancelToken?.throwIfCancelled();
        final url = await _uploadBinaryWithSdk(
          bucket: bucket,
          path: path,
          bytes: bytes,
          contentType: contentType,
        );
        onProgress(1);
        return url;
      }
    }

    return _uploadBinaryWithSdk(
      bucket: bucket,
      path: path,
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<String> _uploadBinaryWithSdk({
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
    ValueChanged<double>? onProgress,
    ProfileMediaUploadCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    final ext = _ext(file);
    final ct = _contentType(isVideo: false, ext: ext, mimeType: file.mimeType);
    final originalBytes = await file.readAsBytes();
    cancelToken?.throwIfCancelled();
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
      cancelToken: cancelToken,
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
    ValueChanged<ProfileMediaResumableProgress>? onResumableProgress,
    ProfileMediaUploadCancelToken? cancelToken,
    String resumableUploadUrl = '',
    int resumableUploadedBytes = 0,
  }) async {
    cancelToken?.throwIfCancelled();
    final ext = _ext(file);
    final ct = _contentType(isVideo: true, ext: ext, mimeType: file.mimeType);
    final name = '$pathSeed.${ext.isEmpty ? 'mp4' : ext}';
    final storagePath = '$uid/videos/$name';
    final previewBytesFuture = _videoPreviewBytes(file);

    final videoBytes = await file.readAsBytes();
    cancelToken?.throwIfCancelled();
    final videoUrl = await _uploadVideoBytes(
      bucket: bucket,
      path: storagePath,
      bytes: videoBytes,
      contentType: ct,
      resumableUploadUrl: resumableUploadUrl,
      resumableUploadedBytes: resumableUploadedBytes,
      onProgress: onProgress,
      onResumableProgress: onResumableProgress,
      cancelToken: cancelToken,
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

  Future<String> _uploadVideoBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
    required String resumableUploadUrl,
    required int resumableUploadedBytes,
    ValueChanged<double>? onProgress,
    ValueChanged<ProfileMediaResumableProgress>? onResumableProgress,
    ProfileMediaUploadCancelToken? cancelToken,
  }) async {
    try {
      return await _uploadBinaryResumable(
        bucket: bucket,
        path: path,
        bytes: bytes,
        contentType: contentType,
        initialUploadUrl: resumableUploadUrl,
        initialUploadedBytes: resumableUploadedBytes,
        onProgress: onProgress,
        onResumableProgress: onResumableProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      cancelToken?.throwIfCancelled();
      final hasStartedResumable =
          resumableUploadUrl.trim().isNotEmpty || resumableUploadedBytes > 0;
      if (hasStartedResumable) {
        rethrow;
      }
      onResumableProgress?.call(
        const ProfileMediaResumableProgress(
          progress: 0,
          uploadUrl: '',
          uploadedBytes: 0,
        ),
      );
      return uploadBinary(
        bucket: bucket,
        path: path,
        bytes: bytes,
        contentType: contentType,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
  }

  Future<String> _uploadBinaryResumable({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
    required String initialUploadUrl,
    required int initialUploadedBytes,
    ValueChanged<double>? onProgress,
    ValueChanged<ProfileMediaResumableProgress>? onResumableProgress,
    ProfileMediaUploadCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    if (bytes.length <= _tusChunkSize && initialUploadUrl.trim().isEmpty) {
      return uploadBinary(
        bucket: bucket,
        path: path,
        bytes: bytes,
        contentType: contentType,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }

    var uploadUrl = initialUploadUrl.trim();
    var offset = initialUploadedBytes.clamp(0, bytes.length);
    if (uploadUrl.isNotEmpty) {
      final remoteOffset = await _tusRemoteOffset(
        bucket: bucket,
        uploadUrl: uploadUrl,
      );
      if (remoteOffset == null) {
        uploadUrl = '';
        offset = 0;
      } else {
        offset = remoteOffset.clamp(0, bytes.length);
      }
    }

    if (uploadUrl.isEmpty) {
      uploadUrl = await _createTusUpload(
        bucket: bucket,
        path: path,
        bytesLength: bytes.length,
        contentType: contentType,
      );
      offset = 0;
    }

    void publishProgress() {
      final progress = bytes.isEmpty ? 1.0 : (offset / bytes.length);
      onProgress?.call(progress.clamp(0.0, 1.0));
      onResumableProgress?.call(
        ProfileMediaResumableProgress(
          progress: progress.clamp(0.0, 1.0),
          uploadUrl: uploadUrl,
          uploadedBytes: offset,
        ),
      );
    }

    publishProgress();
    while (offset < bytes.length) {
      cancelToken?.throwIfCancelled();
      final end = (offset + _tusChunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(offset, end);
      offset = await _patchTusChunk(
        uploadUrl: uploadUrl,
        chunk: chunk,
        offset: offset,
        bucket: bucket,
        cancelToken: cancelToken,
      );
      publishProgress();
    }

    return _sb.storage.from(bucket).getPublicUrl(path);
  }

  Future<String> _createTusUpload({
    required String bucket,
    required String path,
    required int bytesLength,
    required String contentType,
  }) async {
    final storage = _sb.storage.from(bucket);
    final uri = Uri.parse('${storage.url}/upload/resumable');
    final response = await http.post(
      uri,
      headers: {
        ...storage.headers,
        'Tus-Resumable': _tusVersion,
        'Upload-Length': '$bytesLength',
        'Upload-Metadata': _tusMetadata({
          'bucketName': bucket,
          'objectName': path,
          'contentType': contentType,
          'cacheControl': '3600',
        }),
        'x-upsert': 'false',
      },
    );
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw StorageException(
        _storageErrorMessage(response),
        statusCode: '${response.statusCode}',
      );
    }
    final location = response.headers['location'];
    if (location == null || location.trim().isEmpty) {
      throw StorageException('Resumable upload URL was not returned');
    }
    return _absoluteTusUrl(uri, location.trim());
  }

  Future<int?> _tusRemoteOffset({
    required String bucket,
    required String uploadUrl,
  }) async {
    try {
      final storage = _sb.storage.from(bucket);
      final request = http.Request('HEAD', Uri.parse(uploadUrl))
        ..headers.addAll(storage.headers)
        ..headers['Tus-Resumable'] = _tusVersion;
      final response = await request.send();
      if (response.statusCode == 404 || response.statusCode == 410) {
        return null;
      }
      if (response.statusCode < 200 || response.statusCode > 299) {
        return null;
      }
      return int.tryParse(response.headers['upload-offset'] ?? '') ?? 0;
    } catch (_) {
      return null;
    }
  }

  Future<int> _patchTusChunk({
    required String uploadUrl,
    required Uint8List chunk,
    required int offset,
    required String bucket,
    ProfileMediaUploadCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    final storage = _sb.storage.from(bucket);
    final request = http.StreamedRequest('PATCH', Uri.parse(uploadUrl))
      ..headers.addAll(storage.headers)
      ..headers['Tus-Resumable'] = _tusVersion
      ..headers['Content-Type'] = 'application/offset+octet-stream'
      ..headers['Upload-Offset'] = '$offset'
      ..contentLength = chunk.length;
    final responseFuture = request.send();
    try {
      request.sink.add(chunk);
      cancelToken?.throwIfCancelled();
      await request.sink.close();
    } on ProfileMediaUploadCancelled {
      try {
        await request.sink.close();
      } catch (_) {}
      unawaited(
        responseFuture.catchError(
          (_) => http.StreamedResponse(const Stream<List<int>>.empty(), 499),
        ),
      );
      rethrow;
    }
    final streamed = await _waitForUploadResponse(responseFuture, cancelToken);
    final response = await http.Response.fromStream(streamed);
    cancelToken?.throwIfCancelled();
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw StorageException(
        _storageErrorMessage(response),
        statusCode: '${response.statusCode}',
      );
    }
    return int.tryParse(response.headers['upload-offset'] ?? '') ??
        offset + chunk.length;
  }

  String _tusMetadata(Map<String, String> values) {
    return values.entries
        .map((entry) {
          final encoded = base64Encode(utf8.encode(entry.value));
          return '${entry.key} $encoded';
        })
        .join(',');
  }

  String _absoluteTusUrl(Uri endpoint, String location) {
    final parsed = Uri.tryParse(location);
    if (parsed != null && parsed.hasScheme) return location;
    return endpoint.resolve(location).toString();
  }

  Future<void> _uploadBinaryWithProgress({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
    required ValueChanged<double> onProgress,
    ProfileMediaUploadCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
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
    try {
      await for (final chunk in bodyStream) {
        cancelToken?.throwIfCancelled();
        sent += chunk.length;
        request.sink.add(chunk);
        if (total > 0) {
          onProgress((sent / total).clamp(0.0, 1.0));
        }
      }
      cancelToken?.throwIfCancelled();
      await request.sink.close();
    } on ProfileMediaUploadCancelled {
      try {
        await request.sink.close();
      } catch (_) {
        // The socket can already be closed after cancellation.
      }
      unawaited(
        responseFuture.catchError(
          (_) => http.StreamedResponse(const Stream<List<int>>.empty(), 499),
        ),
      );
      rethrow;
    }

    final streamedResponse = await _waitForUploadResponse(
      responseFuture,
      cancelToken,
    );
    final response = await http.Response.fromStream(streamedResponse);
    cancelToken?.throwIfCancelled();
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw StorageException(
        _storageErrorMessage(response),
        statusCode: '${response.statusCode}',
      );
    }
    onProgress(1);
  }

  Future<http.StreamedResponse> _waitForUploadResponse(
    Future<http.StreamedResponse> responseFuture,
    ProfileMediaUploadCancelToken? cancelToken,
  ) async {
    if (cancelToken == null) return responseFuture;
    final result = await Future.any<Object>([
      responseFuture,
      cancelToken.cancelled.then<Object>(
        (_) => throw const ProfileMediaUploadCancelled(),
      ),
    ]);
    return result as http.StreamedResponse;
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
    if (kIsWeb) return ProfileVideoThumbnail.webBytes(xf);
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
